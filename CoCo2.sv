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
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	/*
	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.

	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	*/

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

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign AUDIO_S = 0;
assign AUDIO_L = AUDIO_R;
assign AUDIO_R = sound_pad;
wire sndout;
wire [15:0] sound_pad =  {sndout,sound,casdout,8'b0};
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3;

`include "build_id.v"
localparam CONF_STR = {
	"CoCo2;;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"O4,Overscan,Hidden,Visible;",
	"O3,Artifact,Enable,Disable;",
	"O2,Artifact Phase,Normal,Reverse;",
//	"O58,Count Offset,1,2,3,4;",
	"-;",
	"OA,Swap Joysticks,Off,On;",
	"-;",
	"OB,Debug display,Off,On;",
	"-;",
	"F1,CCCROM,Load Cartridge;",
	"F2,CAS,Load Cassette;",
	"TF,Stop & Rewind;",
	"-;",
	"O7,Turbo,Off,On",
	"-;",
	"O89,Machine,CoCo2,Dragon32,Dragon64",
	"-;",
	"R0,Reset;",
	"J1,Button;",
	"jn,A;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;
wire        ioctl_download;
wire        ioctl_wr;
wire [15:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire  [7:0] ioctl_index;

wire [31:0] joy1, joy2;

wire [15:0] joya1, joya2;


hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_index(ioctl_index),

	.joystick_0(joy1),
   .joystick_1(joy2),

   .joystick_analog_0(joya1),
   .joystick_analog_1(joya2),


	.ps2_key(ps2_key)
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

//////////////////////////////////////////////////////////////////


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;

wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;

wire [5:0] sound;


wire [9:0] center_joystick_y1   =  8'd128 + joya1[15:8];
wire [9:0] center_joystick_x1   =  8'd128 + joya1[7:0];
wire [9:0] center_joystick_y2   =  8'd128 + joya2[15:8];
wire [9:0] center_joystick_x2   =  8'd128 + joya2[7:0];
wire vclk;

wire [31:0] coco_joy1 = status[10] ? joy2 : joy1;
wire [31:0] coco_joy2 = status[10] ? joy1 : joy2;

wire [15:0] coco_ajoy1 = status[10] ? {center_joystick_x2[7:0],center_joystick_y2[7:0]} : {center_joystick_x1[7:0],center_joystick_y1[7:0]};
wire [15:0] coco_ajoy2 = status[10] ? {center_joystick_x1[7:0],center_joystick_y1[7:0]} : {center_joystick_x2[7:0],center_joystick_y2[7:0]};

wire casdout;
wire cas_relay;

reg dragon64;
reg dragon;
reg [1:0]machineselect_r;
reg machine_select_reset;
reg [3:0]reset_count;

always @(posedge clk_sys)
begin
 machine_select_reset <=1'b0;
 dragon64 <= (status[9:8]==2'b10);
 dragon   <= (status[9:8]!=2'b00);
 
 if (machineselect_r!=status[9:8])
	reset_count<=4'b1111;

 if (reset_count>4'b0) begin
  reset_count<=reset_count - 4'b0001;
  machine_select_reset<=1'b1;
 end
 
 machineselect_r<=status[9:8];
end


dragoncoco dragoncoco(
  .clk(clk_sys), // 50 mhz
  .turbo(status[7]&cas_relay),
  .reset(~reset),
  .dragon(dragon),
  .dragon64(dragon64),
  .red(red),
  .green(green),
  .blue(blue),

  .hblank(HBlank),
  .vblank(VBlank),
  .hsync(HSync),
  .vsync(VSync),
  .vclk(vclk),
  // input ps2_clk,
  // input ps2_dat,
  .uart_din(1'b0),

  .ps2_key(ps2_key),
  .ioctl_addr(ioctl_addr),
  .ioctl_data(ioctl_data),
  .ioctl_download(ioctl_download),
  .ioctl_index(ioctl_index),
  .ioctl_wr(ioctl_wr),
  .casdout(casdout),
  .cas_relay(cas_relay),
  .artifact_phase(status[2]),
  .artifact_enable(~status[3]),
  .overscan(status[4]),
//  .count_offset(status[8:5]),
  .joy1(coco_joy1),
  .joy2(coco_joy2),

  .joya1(coco_ajoy1),
  .joya2(coco_ajoy2),


  .sound(sound),
  .sndout(sndout),

  .v_count(VCount),
  .h_count(HCount),
  .DLine1(DLine1),
  .DLine2(DLine2),

  .clk_Q_out(clk_Q_out)

);

wire clk_Q_out;

wire locked;
wire [24:0] sdram_addr;
wire [7:0] sdram_data;
wire sdram_rd;
wire load_tape = ioctl_index == 2;

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

  .rewind(status[15]),
  .en(cas_relay),

  .sdram_addr(sdram_addr),
  .sdram_data(sdram_data),
  .sdram_rd(sdram_rd),

  .data(casdout)
//   .status(tape_status)
);


reg ce_pix;
always @(posedge clk_sys) begin
       ce_pix <= !ce_pix;
end

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = vclk;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;
/*
assign VGA_G  = {green,green[5:4]};
assign VGA_R  = {red,red[4:2]};
assign VGA_B  = {blue,blue[4:2]};
*/


assign VGA_R=rr;
assign VGA_G=gg;
assign VGA_B=bb;


`ifdef USE_OVERLAY
	// mix in overlay!
	wire [7:0]rr = red | {C_R,C_R};
	wire [7:0]gg = green | {C_R,C_R};
	wire [7:0]bb = blue | {C_R,C_R};
`else
	wire [7:0]rr = red;
	wire [7:0]gg = green;
	wire [7:0]bb = blue;
`endif

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1;

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
