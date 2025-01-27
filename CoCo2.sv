//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

// Enable overlay (or not)
`define USE_OVERLAY

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);


///////// Default values for ports not used in this core /////////

//assign ADC_BUS  = 'Z;
assign USER_OUT = '1;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_F1 = 0;
assign VGA_DISABLE = 0;
assign VGA_SCALER = 0;

assign AUDIO_S = 0;
assign AUDIO_L = AUDIO_R;
assign AUDIO_R = sound_pad;
wire sndout;

// sound is mixed:
//
// sndout (1-bit sound) is loudest
// sound is next (12-bit sound from ADC - or top 6 bits is DAC)
// if the user chose to monitor the cassette sound, it it mixed in as a single bit at a low level
//
wire [15:0] sound_pad =  {sndout,sound[11:6], sound[5] ^ (status[13] ? (status[12] ? adc_cassette_bit : casdout) : 1'b0), sound[4:0], 3'b0};
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////


wire ar = status[19];

assign VIDEO_ARX = (!ar) ? 13'd4 : 13'd16;
assign VIDEO_ARY = (!ar) ? 13'd3 : 13'd9;


`include "build_id.v"
`include "build_id_num.v"

localparam CONF_STR = {
	"CoCo2;;",
	"-;",
	"OE,Cart Slot,Cartridge,Disk;",
	"-;",
	"H1F1,CCCROM,Load Cartridge;",
	"H2S0,DSK,Load Disk Drive 0;",
	"H2S1,DSK,Load Disk Drive 1;",
	"H2S2,DSK,Load Disk Drive 2;",
	"H2S3,DSK,Load Disk Drive 3;",
	"-;",
	"OC,Tape Input,File,ADC;",
    "-;",
	"H0F2,CAS,Load Cassette;",
	"H0TR,Stop & Rewind;",
    "-;",
    "H0S4,CAS,Save Cassette;",
    "H0OS,Cass Rwd=0 / Rec=1,0,1;",
    "-;",

	"OD,Monitor Tape Sound,No,Yes;",
	"OQ,Show Tape Status,Yes,No;",
	"-;",
	"P1,Video Settings;",
	"P1-;",
	"P1-, -= Video Settings =-;",
	"P1-;",
	"P1OJ,Aspect ratio,Original,Full Screen;",
	"P1OFH,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;", 
	"P1O4,Overscan,Hidden,Visible;",
	"P1O3,Artifact,Enable,Disable;",
	"P1O2,Artifact Phase,Normal,Reverse;",
//	"O58,Count Offset,1,2,3,4;",
	"-;",
	"OM,Keyboard Layout,PC,CoCo;",
	"OL,D-Pad Joystick emu,No,Yes;",
	"OA,Swap Joysticks,Off,On;",
	"-;",
	"O89,Machine,CoCo2,Dragon32,Dragon64;",
	"O7,Turbo,Off,On;",
	"-;",
`ifdef USE_OVERLAY
	"OB,Debug display,Off,On;",
	"-;",
`endif
	"RN,Hard Reset;",
	"R0,Reset;",
	"J,Button;",
	"jn,A;",
    "V,v",{`BUILD_DATE,"-",`BUILD_NUMBER}
};


//   Status Bit Map:
//               Upper                             Lower              
//   0         1         2         3          4         5         6   
//   01234567890123456789012345678901 23456789012345678901234567890123
//   0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// 

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;
wire        ioctl_download;
wire        ioctl_wr;
wire [15:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire  [7:0] ioctl_index;

// SD block level interface
wire	[4:0]  	img_mounted;
wire				img_readonly;
wire	[19:0] 	img_size;

wire	[31:0] 	sd_lba[5];
wire	[5:0] 	sd_blk_cnt[5];

wire	[4:0]		sd_rd;
wire	[4:0]		sd_wr;
wire	[4:0]		sd_ack;

// SD byte level access. Signals for 2-PORT altsyncram.
wire  [8:0] 	sd_buff_addr;
wire  [7:0] 	sd_buff_dout;
wire  [7:0] 	sd_buff_din[5];
wire        	sd_buff_wr;


wire [31:0] joy1, joy2;

wire [15:0] joya1, joya2;
wire [21:0] gamma_bus;


hps_io #(.CONF_STR(CONF_STR),.VDNUM(5),.BLKSZ(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({dragon,~disk_cart_enabled,disk_cart_enabled,status[12]}),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_index(ioctl_index),

	// 	SD block level interface

	.img_mounted(img_mounted), 		// signaling that new image has been mounted
	.img_readonly(img_readonly), 	// mounted as read only. valid only for active bit in img_mounted
	.img_size(img_size),			// size of image in bytes. 1MB MAX!

	.sd_lba(sd_lba),
	.sd_blk_cnt(sd_blk_cnt), 		// number of blocks-1, total size ((sd_blk_cnt+1)*(1<<(BLKSZ+7))) must be <= 16384!

	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),

	// 	SD byte level access. Signals for 2-PORT altsyncram.
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),


	.joystick_0(joy1),
	.joystick_1(joy2),

	.joystick_l_analog_0(joya1),
	.joystick_l_analog_1(joya2),

	.ps2_key(ps2_key),
	.gamma_bus(gamma_bus)
);


///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys; // 57.272M
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(locked)
);

wire reset = RESET | status[0] | buttons[1] | (ioctl_download & ioctl_index == 1) | machine_select_reset;

/////////////////////// ADC Module  //////////////////////////////


wire [11:0] adc_data;
wire        adc_sync;
reg [11:0] adc_value;
reg adc_sync_d;

integer ii=0;
reg [11:0] adc_val[0:511];
reg [21:0] adc_total = 0;
reg [11:0] adc_avg;

reg adc_cassette_bit;


// interface to ADC via framework
//
ltc2308 #(1, 48000, 50000000) adc_input		// mono, ADC_RATE = 48000, CLK_RATE = 50000000
(
	.reset(reset),
	.clk(CLK_50M),

	.ADC_BUS(ADC_BUS),
	.dout(adc_data),
	.dout_sync(adc_sync)
);

// when data arrives:
//		- latch it in adc_value
//		- keep track of a running average across 512 samples
//
//		-> this average acts as a high-pass filter above roughly 100 Hz while retaining
//		 	while retaining very high frequency response, for possible future fast-load techniques
//
always @(posedge CLK_50M) begin

	adc_sync_d<=adc_sync;
	if(adc_sync_d ^ adc_sync) begin
		adc_value <= adc_data;					// latch in current value, adc_Value
		
		adc_val[0] <= adc_value;				
		adc_total  <= adc_total - adc_val[511] + adc_value;

		for (ii=0; ii<511; ii=ii+1)
			adc_val[ii+1] <= adc_val[ii];
			
		adc_avg <= adc_total[20:9];			// update average value every fetch
		
		if (adc_value < (adc_avg - 100))		// flip the cassette bit if > 0.1V from average
			adc_cassette_bit <= 1;				// note that original CoCo reversed polarity

		if (adc_value > (adc_avg + 100))
			adc_cassette_bit <= 0;
		
	end
end


//////////////////////////////////////////////////////////////////


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;

wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;

wire [11:0] sound;


wire [9:0] center_joystick_y1   =  8'd128 + joya1[15:8];
wire [9:0] center_joystick_x1   =  8'd128 + joya1[7:0];
wire [9:0] center_joystick_y2   =  8'd128 + joya2[15:8];
wire [9:0] center_joystick_x2   =  8'd128 + joya2[7:0];
wire vclk;

wire [31:0] coco_joy1 = status[10] ? joy2 : joy1;
wire [31:0] coco_joy2 = status[10] ? joy1 : joy2;

wire [15:0] coco_ajoy1 = status[10] ? {center_joystick_x2[7:0],center_joystick_y2[7:0]} : {center_joystick_x1[7:0],center_joystick_y1[7:0]};
wire [15:0] coco_ajoy2 = status[10] ? {center_joystick_x1[7:0],center_joystick_y1[7:0]} : {center_joystick_x2[7:0],center_joystick_y2[7:0]};

wire show_cas_overlay = ~status[26];

wire CASS_REWIND_RECORD = status[28];

wire casdout;
wire cas_relay;

reg dragon64;
reg dragon;
reg [1:0]machineselect_r;
reg hard_reset_r;
reg machine_select_reset;
reg [3:0]reset_count;
reg [1:0] hard_reset_state = 2'b00;
reg disk_cart_enabled, disk_cart_enabled_r;
//wire disk_cart_enabled = status[14] & status[9:8]==2'b00;
reg hard_reset;


always @(posedge clk_sys)
begin
 machine_select_reset <=1'b0;
 dragon64 <= (status[9:8]==2'b10);
 dragon   <= (status[9:8]!=2'b00);
 disk_cart_enabled <= (status[14]);
 disk_cart_enabled_r <= disk_cart_enabled;

 if (hard_reset_r!=status[23])
 begin
	reset_count<=4'b1111;
    hard_reset_state = 2'b01;
 end

 if (machineselect_r!=status[9:8])
 begin
	reset_count<=4'b1111;
	hard_reset_state = 2'b01; // for now don't force hard reset when
							  //switching systems
							  // SRH 1/26/25 Added back in to reset whenever system changes [dragon, dragon32, coco2]
 end

 if (disk_cart_enabled_r!=disk_cart_enabled)
 begin
	reset_count<=4'b1111;
	hard_reset_state = 2'b01; // for now don't force hard reset when
							  //switching systems
							  // SRH 1/26/25 Added back in to reset whenever system changes [disk / cart]
 end
 case (hard_reset_state)
	2'b00: 
	begin
	end
	2'b01:
	begin
		hard_reset = 1'b1;
	        hard_reset_state=2'b10;
	end
	2'b10:
	begin
		hard_reset = 1'b0;
	        hard_reset_state=2'b00;
	end
	2'b11:
	begin
	end
 endcase

 if (reset_count>4'b0) begin
  reset_count<=reset_count - 4'b0001;
  machine_select_reset<=1'b1;
 end
 
 machineselect_r<=status[9:8];
 hard_reset_r<=status[23];
end


dragoncoco dragoncoco(
  .clk(clk_sys), // 50 mhz
  .turbo(status[7]),
  .trig_reset_n(~reset),
  .hard_reset(hard_reset),
  .dragon(dragon),
  .dragon64(dragon64),
  .kblayout(~status[22]),
  .red(red),
  .green(green),
  .blue(blue),

  .hblank(HBlank),
  .vblank(VBlank),
  .hsync(HSync),
  .vsync(VSync),
  .vclk(vclk),
  // .sam_a01(sam_a01),
  // input ps2_clk,
  // input ps2_dat,
  .uart_din(1'b0),

  .ps2_key(ps2_key),
  .ioctl_addr(ioctl_addr),
  .ioctl_data(ioctl_data),
  .ioctl_download(ioctl_download),
  .ioctl_index(ioctl_index),
  .ioctl_wr(ioctl_wr),
  .casdout(status[12] ? adc_cassette_bit : casdout),
  .cas_relay(cas_relay),
  .artifact_phase(status[2]),
  .artifact_enable(~status[3]),
  .overscan(status[4]),
//  .count_offset(status[8:5]),

  .joy_use_dpad(status[21]),

  .joy1(coco_joy1),
  .joy2(coco_joy2),

  .joya1(coco_ajoy1),
  .joya2(coco_ajoy2),


  .cass_snd(adc_value),
  .sound(sound),
  .sndout(sndout),

  .v_count(VCount),
  .h_count(HCount),
  .DLine1(DLine1),
  .DLine2(DLine2),

  .clk_Q_out(clk_Q_out),

  // we load the disk ROM instead of cart ram
  .disk_cart_enabled(disk_cart_enabled),
  
  .img_mounted(img_mounted), 	// signaling that new image has been mounted
  .img_readonly(img_readonly), 	// mounted as read only. valid only for active bit in img_mounted
  .img_size(img_size),			// size of image in bytes. 1MB MAX!

  .sd_lba(sd_lba),
  .sd_blk_cnt(sd_blk_cnt), 		// number of blocks-1, total size ((sd_blk_cnt+1)*(1<<(BLKSZ+7))) must be <= 16384!

  .sd_rd(sd_rd),
  .sd_wr(sd_wr),
  .sd_ack(sd_ack),

  // 	SD byte level access. Signals for 2-PORT altsyncram.
  .sd_buff_addr(sd_buff_addr),
  .sd_buff_dout(sd_buff_dout),
  .sd_buff_din(sd_buff_din),
  .sd_buff_wr(sd_buff_wr),
  .CLK50MHZ(CLK_50M),

  .CASS_REWIND_RECORD(CASS_REWIND_RECORD)

);

wire clk_Q_out;

wire locked;
wire [24:0] sdram_addr;
wire [7:0] sdram_data;
wire sdram_rd;
wire load_tape = ioctl_index[5:0] == 2;
reg [24:0] tape_end;
always @(posedge clk_sys) begin
 if (load_tape) tape_end <= ioctl_addr;
end

sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_sys),
	.addr(ioctl_download ? ioctl_addr : sdram_addr),
	.wtbt(0),
	.dout(sdram_data),
	.din(ioctl_data),
	.rd(sdram_rd),
	.we(ioctl_wr & load_tape),
	.ready()
);


cassette cassette(
  .clk(clk_sys),
  .Q(clk_Q_out),

  .rewind(status[27]| (load_tape&ioctl_download)),
  .en(cas_relay),

  .sdram_addr(sdram_addr),
  .sdram_data(sdram_data),
  .sdram_rd(sdram_rd),

  .data(casdout)
//   .status(tape_status)
);

wire [7:0] o_r;
wire [7:0] o_g;
wire [7:0] o_b;

overlay  #( .RGB(24'hFFFFFF) ) coverlay
(
	.reset(reset),
	.i_r(red),
	.i_g(green),
	.i_b(blue),

	.i_clk(clk_sys),
	.i_pix(CE_PIXEL),
	
	.hcnt(HCount),
	.vcnt(VCount),
	
	.o_r(o_r),
	.o_g(o_g),
	.o_b(o_b),
	
	.pos(sdram_addr),
	.max(tape_end),
	.tape_data(sdram_data),
	
	.ena(cas_relay & show_cas_overlay)
);

assign CLK_VIDEO = clk_sys;


wire [2:0] scale = status[17:15];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

assign VGA_SL = sl[1:0];

wire freeze_sync;
wire [3:0] sam_a01;

// debug on USER port (I use a physical oscilloscope and data analyzer)
//assign USER_OUT[0] = sam_a01[1] ;//hblank
//assign USER_OUT[1] = HSync ;
//assign USER_OUT[2] = sam_a01[3]; //hs_n
//assign USER_OUT[3] = '0;
//assign USER_OUT[4] = sam_a01[0]; //sam_a[0]
//assign USER_OUT[5] = sam_a01[2]; //da0
//assign USER_OUT[6] = VSync;

// assign USER_OUT[6:2]='1 ;

video_mixer #(.LINE_LENGTH(380), .GAMMA(1)) video_mixer
(
	.*,

	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),
   .ce_pix(vclk),
	//.scanlines(0),
	.hq2x(scale==1),
	//.mono(0),
	.R(rr),
	.G(gg),
	.B(bb)
	
);


`ifdef USE_OVERLAY
	// mix in overlay!
	wire [7:0]rr = o_r | {C_R,C_R};
	wire [7:0]gg = o_g | {C_R,C_R};
	wire [7:0]bb = o_b | {C_R,C_R};
`else
	wire [7:0]rr = o_r;
	wire [7:0]gg = o_g;
	wire [7:0]bb = o_b;
`endif

// reg  [26:0] act_cnt;
// always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1;

assign LED_USER    = 1'b0;

reg [8:0] HCount,VCount;

// Overlay!

`ifdef USE_OVERLAY

reg [3:0] C_R,C_G,C_B;

wire [159:0]DLine1;
wire [159:0]DLine2;


ovo OVERLAY
(
    .i_r(4'd0),
    .i_g(4'd0),
    .i_b(4'd0),
    .i_clk(clk_sys),

	 .i_Hcount(HCount),
	 .i_VCount(VCount),

    .o_r(C_R),
    .o_g(C_G),
    .o_b(C_B),
    .ena(status[11]),

    .in0(DLine1),
    .in1(DLine2)
);

`endif


endmodule
