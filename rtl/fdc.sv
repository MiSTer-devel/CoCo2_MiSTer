////////////////////////////////////////////////////////////////////////////////
// Project Name:	COCO3 Targeting MISTer 
// File Name:		fdc.v
//
// Floppy Disk Controller for MISTer
//
////////////////////////////////////////////////////////////////////////////////
//
// Code based partily on work by Gary Becker
// Copyright (c) 2008 Gary Becker (gary_l_becker@yahoo.com)
//
// Floopy Disk Controller by Stan Hodge (stan.pda@gmail.com)
// Copyright (c) 2021 by Stan Hodge (stan.pda@gmail.com)
//
// All rights reserved

// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Please report bugs to the author, but before you do so, please
// make sure that this is not a derivative work and that
// you have the latest version of this file.
//
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////



module fdc(
	input        		CLK,     		// clock
	input        		RESET_N,	   	// async reset
	input        		HDD_EN,
	input				RW_N,
	input  		[3:0]	ADDRESS,       	// i/o port addr [extended for coco]
	input  		[7:0]	DATA_IN,        // data in
	output 		[7:0] 	DATA_HDD,      	// data out
	output       		HALT,         	// DMA request
	output       		NMI_09,

// 	SD block level interface

	input 		[3:0]	img_mounted, 	// signaling that new image has been mounted
	input				img_readonly, 	// mounted as read only. valid only for active bit in img_mounted
	input 		[19:0] 	img_size,    	// size of image in bytes. 1MB MAX!

	output		[31:0] 	sd_lba[4],
	output		[5:0]	sd_blk_cnt[4],	// number of blocks-1, total size ((sd_blk_cnt+1)*(1<<(BLKSZ+7))) must be <= 16384!
	output reg	[3:0]	sd_rd,
	output reg  [3:0]	sd_wr,
	input       [3:0]	sd_ack,

// 	SD byte level access. Signals for 2-PORT altsyncram.
	input  		[8:0]	sd_buff_addr,
	input  		[7:0] 	sd_buff_dout,
	output 		[7:0] 	sd_buff_din[4],
	input        		sd_buff_wr,
	
	output		[7:0]	probe
);


wire	[7:0]	DRIVE_SEL_EXT;
wire			MOTOR;
wire			WRT_PREC;
wire			DENSITY;
wire			HALT_EN;
wire 			INTRQ;
wire			DRQ;

wire			WR;
wire			RD;
wire			CE;
wire			HALT_EN_RST;
wire	[7:0]	DATA_1793;

// Generate a 1 Mhz enable for the fdc... and control writes
wire ena_1Mhz;
wire [5:0]	div_1mhz;

assign ena_1Mhz = (div_1mhz == 6'd49) ? 1'b1: 1'b0;

always@(negedge CLK or negedge RESET_N)
begin
	if (~RESET_N)	div_1mhz <= 6'd0;
	else
		begin
			if (ena_1Mhz)
				div_1mhz <= 6'd0;
			else
				div_1mhz <= div_1mhz + 6'd1;
		end
end

// Diagnostics only
assign probe = {temp_sd_ack, WR, RD, prepare, NMI_09, HALT};

//FDC read data path.  =$ff40 or wd1793
assign	DATA_HDD =		({HDD_EN, ADDRESS[3:0]} == 5'h10)	?	{HALT_EN, 
																DRIVE_SEL_EXT[3],
																DENSITY, 
																WRT_PREC, 
																MOTOR, 
																DRIVE_SEL_EXT[2:0]}:
						(CE == 1'b1)						?	DATA_1793:
																8'h00;

// Control signals for the wd1793
assign WR = (~RW_N && CE);
assign RD = (RW_N && CE);
assign CE = (HDD_EN && ADDRESS[3]);


//	NMI from disk controller
assign	NMI_09	=	DENSITY && INTRQ;				// Send NMI if Double Density (Halt Mode)

//	HALT from disk controller
assign	HALT	=	HALT_EN && ~DRQ;

assign	HALT_EN_RST = RESET_N && ~INTRQ; // From controller schematic

// $ff40 control register [part 1]
always @(negedge CLK or negedge RESET_N)
begin
	if(!RESET_N)
	begin
		DRIVE_SEL_EXT <= 8'h00;
		MOTOR <= 1'b0;
		WRT_PREC <= 1'b0;
		DENSITY <= 1'b0;
	end
	else
	begin
		if (ena_1Mhz)
		begin
			case ({RW_N, HDD_EN, ADDRESS[3:0]})
			6'b010000:
			begin
				DRIVE_SEL_EXT <= 	{4'b0000,
									DATA_IN[6],		// Drive Select [3] / Side Select
									DATA_IN[2:0]};		// Drive Select [2:0]
				MOTOR <= DATA_IN[3];					// Turn on motor, not used here just checked, 0=MotorOff 1=MotorOn
				WRT_PREC <= DATA_IN[4];				// Write Precompensation, not used here
				DENSITY <= DATA_IN[5];					// Density, not used here just checked
			end
			endcase
		end
	end
end

// $ff40 control register [part 2]
always @(negedge CLK or negedge HALT_EN_RST)
begin
	if(!HALT_EN_RST)
	begin
		HALT_EN <= 1'b0;
	end
	else
	begin
		if (ena_1Mhz)
		begin
			case ({RW_N, HDD_EN, ADDRESS[3:0]})
			6'b010000:
			begin
				HALT_EN <= DATA_IN[7];					// Normal Halt enable, 0=Disabled 1=Enabled
			end
			endcase
		end
	end
end

// SD blk system is a array of 4 systems - one for each drive.  Note - some signals are shared between sd blk drives.
// The wd1793 does not handle talking to more than 1 drive at a time.  The following selects [de-muxes] the sd
// blk interfaces down to a single interface for the wd1793.

wire	[2:0]	drive_index;
wire 	[7:0]	temp_sd_buf_din;
wire			temp_sd_rd;
wire			temp_sd_wr;
wire	[31:0]	temp_sd_lba;
wire			temp_img_mounted;
wire			temp_sd_ack;
wire			prepare;

assign 	drive_index = 	(DRIVE_SEL_EXT[3:0] == 4'b1000)	?	3'd3: 
						(DRIVE_SEL_EXT[3:0] == 4'b0100)	?	3'd2:
						(DRIVE_SEL_EXT[3:0] == 4'b0010)	?	3'd1:
															3'd0;
// The write input to the sd block interface all comes from the same interface on the wd1793.
assign sd_buff_din[3] = temp_sd_buf_din;
assign sd_buff_din[2] = temp_sd_buf_din;
assign sd_buff_din[1] = temp_sd_buf_din;
assign sd_buff_din[0] = temp_sd_buf_din;

// The wd1793 will allways transfer 1 blk. This is blk qty - 1 per spec.
assign sd_blk_cnt[3] = 6'd0;
assign sd_blk_cnt[2] = 6'd0;
assign sd_blk_cnt[1] = 6'd0;
assign sd_blk_cnt[0] = 6'd0;

// Demux of the proper sd rd command bit on the bus of 4
assign sd_rd = 			(drive_index == 3'd3)			?	{temp_sd_rd,3'b000}:
						(drive_index == 3'd2)			?	{1'b0,temp_sd_rd,2'b00}:
						(drive_index == 3'd1)			?	{2'b00,temp_sd_rd,1'b0}:
															{3'b000,temp_sd_rd};

// Demux of the proper sd wr command bit on the bus of 4
assign sd_wr = 			(drive_index == 3'd3)			?	{temp_sd_wr,3'b000}:
						(drive_index == 3'd2)			?	{1'b0,temp_sd_wr,2'b00}:
						(drive_index == 3'd1)			?	{2'b00,temp_sd_wr,1'b0}:
															{3'b000,temp_sd_wr};

// This places the lba address generated from the wd1793 on the proper sd_lba bus of the active drive.
assign sd_lba[3]=		(drive_index == 3'd3)			?	temp_sd_lba:
															32'd0;

assign sd_lba[2]=		(drive_index == 3'd2)			?	temp_sd_lba:
															32'd0;

assign sd_lba[1]=		(drive_index == 3'd1)			?	temp_sd_lba:
															32'd0;

assign sd_lba[0]=		(drive_index == 3'd0)			?	temp_sd_lba:
															32'd0;

// Demux of the proper sd ack command bit on the bus of 4
assign temp_sd_ack =		(drive_index == 3'd3)		?	sd_ack[3]:
							(drive_index == 3'd2)		?	sd_ack[2]:
							(drive_index == 3'd1)		?	sd_ack[1]:
															sd_ack[0];

wire			drive_ready[4];
wire	[19:0]	drive_size[4];
wire			drive_wp[4];

wire			active_drive_ready;
wire			active_drive_size;
wire			active_drive_wp;


// As drives are mounted in MISTer this logic saves the ready, size, and write protect for
// changing drives to the wd1793.

// Drive 0

always @(negedge img_mounted[0] or negedge RESET_N)
begin
	if (~RESET_N)
		drive_ready[0] <= 1'b0;
	else
		begin
			drive_ready[0] <= 1'b1;
			drive_size[0] <= img_size;
			drive_wp[0] <= img_readonly;
		end
end

// Drive 1

always @(negedge img_mounted[1] or negedge RESET_N)
begin
	if (~RESET_N)
		drive_ready[1] <= 1'b0;
	else
		begin
			drive_ready[1] <= 1'b1;
			drive_size[1] <= img_size;
			drive_wp[1] <= img_readonly;
		end
end

// Drive 2

always @(negedge img_mounted[2] or negedge RESET_N)
begin
	if (~RESET_N)
		drive_ready[2] <= 1'b0;
	else
		begin
			drive_ready[2] <= 1'b1;
			drive_size[2] <= img_size;
			drive_wp[2] <= img_readonly;
		end
end

// Drive 3

always @(negedge img_mounted[3] or negedge RESET_N)
begin
	if (~RESET_N)
		drive_ready[3] <= 1'b0;
	else
		begin
			drive_ready[3] <= 1'b1;
			drive_size[3] <= img_size;
			drive_wp[3] <= img_readonly;
		end
end

// The following logic generates a pulse with the saved drive infomation above
// when the computer changes drives.


wire		[3:0]	drive_sel_ext_d;
wire				drive_0_change;
wire				drive_1_change;
wire				drive_2_change;
wire				drive_3_change;
wire				pulse_start;
wire		[7:0]	pulse_time;
wire		[3:0]	changed_drive;

// detect drive changes
assign drive_0_change = DRIVE_SEL_EXT[0] && ~drive_sel_ext_d[0];
assign drive_1_change = DRIVE_SEL_EXT[1] && ~drive_sel_ext_d[1];
assign drive_2_change = DRIVE_SEL_EXT[2] && ~drive_sel_ext_d[2];
assign drive_3_change = DRIVE_SEL_EXT[3] && ~drive_sel_ext_d[3];


always @(negedge CLK or negedge RESET_N)
begin
	if (~RESET_N)
	begin
		active_drive_ready <= 1'b0;
		active_drive_size <= 20'b0;
		active_drive_wp <= 1'b0;
		pulse_time <= 7'b0;
		pulse_start <= 1'b0;
		temp_img_mounted <= 1'b0;
		changed_drive <= 4'd8;
	end
	else
	begin
//		Delay for drive detection
		drive_sel_ext_d <= DRIVE_SEL_EXT;

//		When a drive change detection occurs, log the drive and start a pulse generation which looks
//		just like the img_mounted signal from the SD blk interface.  Additionally supply the wd1793 the
//		saved drive data.

		if (drive_0_change)
		begin
			changed_drive <= 4'd0;
			pulse_start <= 1'b1;
		end
		if (drive_1_change)
		begin
			changed_drive <= 4'd1;
			pulse_start <= 1'b1;
		end
		if (drive_2_change)
		begin
			changed_drive <= 4'd2;
			pulse_start <= 1'b1;
		end
		if (drive_3_change)
		begin
			changed_drive <= 4'd3;
			pulse_start <= 1'b1;
		end

		if (pulse_start)
		begin
//			Hold off on generating a img_mounted pulse if no drive has been mounted.
			if (changed_drive < 4'd4)
			begin
				if (drive_ready[changed_drive])
				begin

					pulse_time <= pulse_time + 7'd1;

					if (pulse_time == 7'd1)
					begin
						active_drive_ready <= drive_ready[changed_drive];
						active_drive_size <= drive_size[changed_drive];
						active_drive_wp <= drive_wp[changed_drive];
						temp_img_mounted <= 1'b0;
					end

					if (pulse_time == 7'd2)
					begin
						temp_img_mounted <= 1'b1;
					end

					if (pulse_time == 7'd120)
					begin
						temp_img_mounted <= 1'b0;
						pulse_start <= 1'b0;
						pulse_time <= 7'b0;
						changed_drive <= 4'd8;
					end
				end
				else
					active_drive_ready <= 1'b0;
			end
		end
	end
end

wd1793 #(1) coco_wd1793
(
	.clk_sys(~CLK),
	.ce(ena_1Mhz),
	.reset(~RESET_N),
	.io_en(1'b1),
	.rd(RD),
	.wr(WR),
	.addr(ADDRESS[1:0]),
	.din(DATA_IN),
	.dout(DATA_1793),
	.drq(DRQ),
	.intrq(INTRQ),

	.img_mounted(img_mounted[0]),
	.img_size(img_size),
//	.img_mounted(temp_img_mounted),
//	.img_size(active_drive_size),
	.prepare(prepare),

	.sd_lba(temp_sd_lba),
	.sd_rd(temp_sd_rd),
	.sd_wr(temp_sd_wr), 
	.sd_ack(temp_sd_ack),

	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(temp_sd_buf_din), 
	.sd_buff_wr(sd_buff_wr),

	.wp(active_drive_wp),

	.size_code(3'd5),		// 5 is 18 sector x 256 bits COCO standard
	.layout(1'b1),			// 0 = Track-Side-Sector, 1 - Side-Track-Sector
	.side(1'b0),			// Not support DS yet.
//	.ready(active_drive_ready),
	.ready(1'b1),

	.input_active(0),
	.input_addr(0),
	.input_data(0),
	.input_wr(0),
	.buff_din(0)
);

endmodule
