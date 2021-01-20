

// todo: find a better name
module dragoncoco(
  input clk, // 42.954 mhz
  input turbo,
  input reset, // todo: reset doesn't work!
  input dragon,
  input dragon64,
  input kblayout,

  // video signals
  output [7:0] red,
  output [7:0] green,
  output [7:0] blue,

  output hblank,
  output vblank,
  output hsync,
  output vsync,
  
  // clocks output
  output vclk,
  output clk_Q_out,

  // video options
  input artifact_phase,
  input artifact_enable,
  input overscan,


  input uart_din,  // not connected yet

  // keyboard
  input [10:0] ps2_key,

  // joystick input
  // digital for buttons
  input [15:0] joy1,  
  input [15:0] joy2,
  // analog for position
  input [15:0] joya1,
  input [15:0] joya2,
  input joy_use_dpad,

  
  // roms, cartridges, etc
  input [7:0] ioctl_data,
  input [15:0] ioctl_addr,
  input ioctl_download,
  input ioctl_wr,
  input ioctl_index,


  // cassette signals
  input casdout,
  output cas_relay,
  
  // sound
  input [11:0] cass_snd,
  output [11:0] sound,
  output sndout,
  
  // debug for video overlay
  output [8:0] v_count,
  output [8:0] h_count,
  output [159:0] DLine1,
  output [159:0] DLine2

);

assign clk_Q_out = clk_Q;

wire nmi = 1'b1;
wire halt = 1'b1;

wire clk_E, clk_Q;


reg clk_14M318_ena ;
reg [1:0] count;


always @(posedge clk)
begin
	if (~reset)
		count<=0;
	else
	begin
		clk_14M318_ena <= 0;
		if (count == 'd2)
		begin
		  clk_14M318_ena <= 1;
        count <= 0;
		end
		else
		begin
			count<=count+1;
		end
	end
end

reg clk_28M_ena ;
reg [1:0] count2;

always @(posedge clk)
begin
	if (~reset)
		count2<=0;
	else
	begin
		clk_28M_ena <= 0;
		if (count2 == 'd1)
		begin
		  clk_28M_ena <= 1;
        count2 <= 0;
		end
		else
		begin
			count2<=count2+1;
		end
	end
end
wire clk_enable = turbo ? clk_28M_ena : clk_14M318_ena;


wire [7:0] cpu_dout;
wire [15:0] cpu_addr;
wire cpu_rw;
wire cpu_bs;
wire cpu_ba;
wire cpu_adv_valid_addr;
wire cpu_busy;
wire cpu_last_inst_cycle;
wire irq;
wire firq;



wire ram_cs,rom8_cs,romA_cs,romC_cs,io_cs,pia1_cs,pia_cs,pia_orig_cs;


wire [7:0]vdg_data;
reg [7:0] ram_dout;
reg [7:0] ram_dout_b;
wire [7:0] rom8_dout;
reg [7:0] rom8_dout2;
wire [7:0] romA_dout;
reg [7:0] romA_dout2;
wire [7:0] romC_dout;
reg [7:0] romC_dout2;
wire [7:0] pia_dout;
reg [7:0] pia_dout2;
wire [7:0] pia1_dout;
reg [7:0] pia1_dout2;
wire [7:0] io_out;

wire we = ~cpu_rw & clk_E;


wire [7:0] keyboard_data;
wire [7:0] kb_cols, kb_rows;

wire [7:0] pia1_portb_out;

// data mux
/*
wire [7:0] cpu_din =
  ram_cs  ? ram_dout  :
  rom8_cs ? rom8_dout :
  romA_cs ? romA_dout :
  romC_cs ? romC_dout :
  pia_cs  ? pia_dout  :
  pia1_cs ? pia1_dout :
  io_cs   ? io_out : 8'hff;
*/
wire [7:0] cpu_din;
reg [7:0] data_hold;
always_comb begin
   unique case (1'b1)
     ram_cs:  cpu_din =  ram_dout;
     rom8_cs: cpu_din =  rom8_dout2;
     romA_cs: cpu_din =  romA_dout2;
     romC_cs: cpu_din =  romC_dout2;
     pia_cs:  cpu_din =  pia_dout2;
     pia1_cs: cpu_din =  pia1_dout2;
     io_cs:   cpu_din =  io_out;
     default: cpu_din =  8'hff;
   endcase
	
end


/*
Dragon 64 has two hardware changes to access more I/O

cpu_addr[2] is used as a select between the pia and the ACIA serial

pia_portb_out[2] switches between the rom and alternative rom chip
*/


assign pia_cs = dragon64 ? pia_64_cs : pia_orig_cs ;             

wire pia_64_cs= ~cpu_addr[2] & pia_orig_cs;
wire acia_cs = cpu_addr[2] &  pia_orig_cs ;
wire rom8_1_cs = rom8_cs & ~pia1_portb_out[2];
wire rom8_2_cs = rom8_cs & pia1_portb_out[2];
wire romA_1_cs = romA_cs & ~pia1_portb_out[2];
wire romA_2_cs = romA_cs & pia1_portb_out[2];

wire [7:0] cpu_din64;

always_comb begin
   unique case (1'b1)
     ram_cs:     cpu_din64 =  ram_dout;
     rom8_1_cs:  cpu_din64 =  rom8_64_1_2;
     rom8_2_cs:  cpu_din64 =  rom8_64_2_2;
     romA_1_cs:  cpu_din64 =  romA_64_1_2;
     romA_2_cs:  cpu_din64 =  romA_64_2_2;
     romC_cs:    cpu_din64 =  romC_dout2;
	  acia_cs:    cpu_din64 =  acia_dout;
     pia_cs:     cpu_din64 =  pia_dout2;
     pia1_cs:    cpu_din64 =  pia1_dout2;
     io_cs:      cpu_din64 =  io_out;
     default:    cpu_din64 =  8'hff;
   endcase
end

mc6809i cpu(
  .clk(clk),
  .D(dragon64?cpu_din64:cpu_din),
  .DOut(cpu_dout),
  .ADDR(cpu_addr),
  .RnW(cpu_rw),
  .E(clk_E),
  .Q(clk_Q),
  .BS(cpu_bs),
  .BA(cpu_ba),
  .nIRQ(~irq),
  .nFIRQ(~firq),
  .nNMI(nmi),
  .AVMA(cpu_adv_valid_addr),
  .BUSY(cpu_busy),
  .LIC(cpu_last_inst_cycle),
  .nHALT(halt),
  .nRESET(reset),
  .nDMABREQ(1)
);

dpram #(.addr_width_g(16), .data_width_g(8)) ram1(
  .clock_a(clk),
  .address_a(cpu_addr),
  .data_a(cpu_dout),
  .q_a(/*ram_dout*/),
  .wren_a(we),
  .enable_a(ram_cs),
  .enable_b(1'b1),
/*  .wren_a(~sam_we_n),
  .enable_a(sam_we_n),
  .enable_b(sam_we_n),
*/
  //.clock_b(clk),
  //.address_b(vmem),
  //.q_b(ram_dout_b)
  .clock_b(clk),
  .address_b(sam_a),
  .q_b(vdg_data)
);

// 8k extended basic rom
// Do we need an option to enable/disable extended basic rom?
assign rom8_dout = dragon ?   rom8_dout_dragon : rom8_dout_tandy;
wire [7:0] rom8_dout_dragon;
wire [7:0] rom8_dout_tandy;

rom_ext rom8(
  .clk(clk),
  .addr(cpu_addr[12:0]),
  .dout(rom8_dout_tandy),
  .cs(~rom8_cs)
);
dragon_ext rom8_D(
  .clk(clk),
  .addr(cpu_addr[12:0]),
  .dout(rom8_dout_dragon),
  .cs(~rom8_cs)
);


assign romA_dout = dragon ?  romA_dout_dragon : romA_dout_tandy;
wire [7:0] romA_dout_dragon;
wire [7:0] romA_dout_tandy;

// 8k color basic rom
rom_bas romA(
  .clk(clk),
  .addr(cpu_addr[12:0]),
  .dout(romA_dout_tandy),
  .cs(~romA_cs)
);

dragon_bas romA_D(
  .clk(clk),
  .addr(cpu_addr[12:0]),
  .dout(romA_dout_dragon),
  .cs(~romA_cs )
 );

 
 

//
// Dragon 64 has two banks of 16k roms. We split them into 
// 4 banks of 8. Not sure this is the best idea..
// 
reg [7:0] rom8_64_1_2;
reg [7:0] rom8_64_2_2;
reg [7:0] romA_64_1_2;
reg [7:0] romA_64_2_2;

wire [7:0] rom8_64_1;
wire [7:0] rom8_64_2;
wire [7:0] romA_64_1;
wire [7:0] romA_64_2;

 
dragon_ext64 rom8_D64_1(
  .clk(clk),
  .addr(cpu_addr[12:0]),
  .dout(rom8_64_1),
  .cs(~rom8_cs)
);
 
dragon_bas64 romA_D64_1(
  .clk(clk),
  .addr(cpu_addr[12:0]),
  .dout(romA_64_1),
  .cs(~romA_cs )
 );

dragon_alt_ext64 rom8_D64_2(
  .clk(clk),
  .addr(cpu_addr[12:0]),
  .dout(rom8_64_2),
  .cs(~rom8_cs)
);
 
dragon_alt_bas64 romA_D64_2(
  .clk(clk),
  .addr(cpu_addr[12:0]),
  .dout(romA_64_2),
  .cs(~romA_cs )
 );
 
 


// there must be another solution
reg cart_loaded;
always @(posedge clk)
  if (load_cart & ioctl_download & ~ioctl_wr)
    cart_loaded <= ioctl_addr > 15'h100;

wire load_cart = ioctl_index == 1;

dpram #(.addr_width_g(14), .data_width_g(8)) romC(
  .clock_a(clk),
  .address_a(cpu_addr[13:0]),
  .q_a(romC_dout),
  .enable_a(romC_cs),

  .clock_b(clk),
  .address_b(ioctl_addr[13:0]),
  .data_b(ioctl_data),
  .wren_b(ioctl_wr & load_cart)
);




wire [2:0] s_device_select;



wire da0;
wire [7:0] ma_ram_addr;
wire ras_n, cas_n,sam_we_n;
reg [15:0] sam_a;
reg ras_n_r;
reg cas_n_r;
reg q_r;

always @(posedge clk)
begin
	if (~reset)
	begin
		ras_n_r<=0;
		cas_n_r<=0;
		q_r<=0;
	end
	else if  (clk_enable == 1)
	begin
	     if (ras_n == 1 && ras_n_r == 0  && clk_E ==1)
		  begin
		    //  ram_datao <= sram_i.d(ram_datao'range);
			ram_dout<=vdg_data;
			romC_dout2<=romC_dout;
			romA_dout2<=romA_dout;
			rom8_dout2<=rom8_dout;
			pia_dout2<=pia_dout;
			pia1_dout2<=pia1_dout;
			rom8_64_1_2<=rom8_64_1;
			rom8_64_2_2<=rom8_64_2;
			romA_64_1_2<=romA_64_1;
			romA_64_2_2<=romA_64_2;

        end
        if (ras_n == 0 && ras_n_r == 1)
          sam_a[7:0]<= ma_ram_addr;
        else if (cas_n == 0 && cas_n_r == 1)
          sam_a[15:8] <= ma_ram_addr;

		  if (clk_Q == 1 && q_r == 0)
		  begin
		   ram_dout_b<=vdg_data;// <= sram_i.d(ram_datao'range);
        end
        q_r <= clk_Q;


        ras_n_r <= ras_n;
        cas_n_r <= cas_n;
	end
end
			//assign ram_dout=vdg_data;


mc6883 sam(
			.clk(clk),
			.clk_ena(clk_enable),
			.reset(~reset),

			//-- input
			.addr(cpu_addr),
			.rw_n(cpu_rw),

			//-- vdg signals
			.da0(da0),
			.hs_n(hs_n),
			.vclk(), // not sure why this clock doesn't work to put it into the video chip

			//-- peripheral address selects
			.s_device_select(s_device_select),

			//-- clock generation
			.clk_e(clk_E),
			.clk_q(clk_Q),

			//-- dynamic addresses
			.z_ram_addr(ma_ram_addr),

			//-- ram
			.ras0_n(ras_n),
			.cas_n(cas_n),
			.we_n(sam_we_n),

			.dbg()//sam_dbg
);


wire nc;
wire [7:0] cs74138;
assign {
  nc,io_cs, pia1_cs, pia_orig_cs,
  romC_cs, romA_cs, rom8_cs,
  ram_cs
} = cs74138;

ttl_74ls138_p u11(
.a(s_device_select[0]),
.b(s_device_select[1]),
.c(s_device_select[2]),
.g1(1),//comes from CART_SLENB#
.g2a(1),//come from E NOR cs_sel(2)
.g2b(1),
//.g2a( ~(cpu_rw | S[2])),
//.g2b(~(E| S[2])),//come from E NOR cs_sel(2)
.y(cs74138)
);



wire fs_n;
wire hs_n;

pia6520 pia(
  .data_out(pia_dout),
  .data_in(cpu_dout),
  .addr(cpu_addr[1:0]),
  .strobe(pia_cs),
  .we(we),
  .irq(irq),
  .porta_in(kb_rows),
  .porta_out(),
  .portb_in(),
  .portb_out(kb_cols),
  .ca1_in(hs_n),
  .ca2_in(),
  .cb1_in(fs_n),  
  .cb2_in(),
  .ca2_out(sela), // used for joy & snd
  .cb2_out(selb), // used for joy & snd
  .clk(clk),
  .clk_ena(clk_enable),
  .reset(~reset)
);


wire casdin0;
wire rsout1;
wire [5:0] dac_data;
wire sela,selb;
wire snden;
// 1 bit sound
assign sndout = pia1_portb_out[1];

pia6520 pia1(
  .data_out(pia1_dout),
  .data_in(cpu_dout),
  .addr(cpu_addr[1:0]),
  .strobe(pia1_cs),
  .we(we),
  .irq(firq),
  .porta_in({6'd0,casdout}),
  .porta_out({dac_data,casdin0,rsout1}),
  .portb_in(dragon64?8'b00000001:8'b00000000), // from dragon64 schematic 
  .portb_out(pia1_portb_out),
  .ca1_in(dragon64?1'b1:1'b0), // from dragon64 schematic - this should be held high
  .ca2_in(),
  .cb1_in(cart_loaded & reset & clk_Q), // cartridge inserted
  .cb2_in(),
  .ca2_out(cas_relay),
  .cb2_out(snden),
  .clk(clk),
  .clk_ena(clk_enable),
  .reset(~reset)
);



assign DLine1 = {

5'b10000,						// space
5'b11111,						// '#'  (to mark the data)
1'b0,pia1_portb_out[7:4],
5'b10000,						// space

5'b10101,						// '>'  (to mark the data)
1'b0,pia1_portb_out[3:0],
5'b10000,						// space

5'b11010,						// ':'  (to mark the data)
3'b0,ram_dout_b[7:6],
5'b10000,						// space

110'b0};

// two is a copy of 1 for now, but we will use this for debugging
// the disk controller
assign DLine2 = {

5'b10000,						// space
5'b11111,						// '#'  (to mark the data)
1'b0,pia1_portb_out[7:4],
5'b10000,						// space

5'b10101,						// '>'  (to mark the data)
1'b0,pia1_portb_out[3:0],
5'b10000,						// space

5'b11010,						// ':'  (to mark the data)
3'b0,ram_dout_b[7:6],
5'b10000,						// space

110'b0};

mc6847pace vdg(
  .clk(clk),
  .clk_ena(clk_enable),//VClk - vclk doesn't seem to work
  .reset(~reset),
  .da0(da0),
  .dd(ram_dout_b),
  .hs_n(hs_n),
  .fs_n(fs_n),
  .an_g(pia1_portb_out[7]), // PIA1 port B
  .an_s(ram_dout_b[7]),
  .intn_ext(pia1_portb_out[4]),
  .gm(pia1_portb_out[6:4]), // [2:0] pin 6 (gm2),5 (gm1) & 4 (gm0) PIA1 port B
  .css(pia1_portb_out[3]),
  .inv(ram_dout_b[6]),
  .red(red),
  .green(green),
  .blue(blue),
  .hsync(hsync),
  .vsync(vsync),
  .hblank(hblank),
  .vblank(vblank),
  .artifact_enable(artifact_enable),
  .artifact_set(1'b0),
  .artifact_phase(artifact_phase),
  .overscan(overscan),

  .o_v_count(v_count),
  .o_h_count(h_count),


  .pixel_clock(vclk),
  .cvbs()
);



// hilo comes from the dac as the comparator 
// of whether the joystick value is higher or lower than the amount being probed
// we need to pass it through the keyboard matrix so it flows into here
wire hilo;
keyboard kb(
.clk_sys(clk),
.reset(~reset),
.dragon(dragon),
.ps2_key(ps2_key),
.addr(kb_cols),
.kb_rows(kb_rows),
.kblayout(kblayout),
.Fn(),
.modif(),
.joystick_1_button(joy1[4]),
.joystick_2_button(joy2[4]),
.joystick_hilo(hilo)

);


// the DAC isn't really a DAC but represents the DAC chip on the schematic. 
// All the signals have been digitized before it gets here.

reg [15:0] dac_joya1;
reg [15:0] dac_joya2;

always @(clk) begin

	if (joy_use_dpad)
	  begin
		dac_joya1[15:8] <= 8'd128;
		dac_joya1[7:0]  <= 8'd128;
		
		dac_joya2[15:8] <= 8'd128;
		dac_joya2[7:0]  <= 8'd128;
		
		if (joy1[0])	// right
			dac_joya1[15:8] <= 8'd240;

		if (joy1[1])	// left
			dac_joya1[15:8] <= 8'd16;
		
		if (joy1[2])	// down
			dac_joya1[7:0] <= 8'd240;

		if (joy1[3])	// up
			dac_joya1[7:0] <= 8'd16;
		
		if (joy2[0])	// right
			dac_joya2[15:8] <= 8'd240;

		if (joy2[1])	// left
			dac_joya2[15:8] <= 8'd16;
		
		if (joy2[2])	// down
			dac_joya2[7:0] <= 8'd240;

		if (joy2[3])	// up
			dac_joya2[7:0] <= 8'd16;
	  end
	else
	  begin
		dac_joya1 <= joya1;
		dac_joya2 <= joya2;
	  end
end

dac dac(
.clk(clk),
.joya1(dac_joya1),
.joya2(dac_joya2),
.dac(dac_data),
.cass_snd(cass_snd),
.snden(snden),
.snd(),
.hilo(hilo),
.selb(selb),
.sela(sela),
.sound(sound)

);

//dragon 64 has a serial module wired in based on addr[2] - this module is a stub that returns values to make things work 
wire [7:0] acia_dout;
acia acia (
   .clk(clk),
   .addr(cpu_addr[2:0]),
   .data(acia_dout)
  );

endmodule
