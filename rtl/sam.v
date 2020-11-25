
/*

SAM - WIP

chip select signal S:
0 ram  0000-7fff
1 rom8 8000-9fff exp rom
2 romA a000-bfff basic rom
3 romC c000-feff cartridge
4 pia1 ff00-ff1f (ff00-ff03)
5 pia2 ff20-ff3f (ff20-ff23)
- n/a  ff40-ff5f
7/2 ffc0-ffff

  ffc0-ffc5 SAM VDG Mode registers V0-V2
  ffc0/ffc1 SAM VDG Reg V0
  ffc2/ffc3 SAM VDG Reg V1
  ffc3/ffc5 SAM VDG Reg V2
  ffc6-ffd3 SAM Display offset in 512 byte pages F0-F6
  ffc6/ffc7 SAM Display Offset bit F0
  ffc8/ffc9 SAM Display Offset bit F1
  ffca/ffcb SAM Display Offset bit F2
  ffcc/ffcd SAM Display Offset bit F3
  ffce/ffcf SAM Display Offset bit F4
  ffd0/ffc1 SAM Display Offset bit F5
  ffd2/ffc3 SAM Display Offset bit F6
  ffd4/ffd5 SAM Page #1 bit - in D64 maps upper 32K Ram to $0000 to $7fff
  ffd6-ffd9 SAM MPU Rate R0-R1
  ffd6/ffd7 SAM MPU Rate bit R0
  ffd8/ffd9 SAM MPU Rate bit R1
  ffda-ffdd SAM Memory Size select M0-M1
  ffda/ffdb SAM Memory Size select bit M0
  ffdc/ffdd SAM Memory Size select bit M1
  ffde/ffdf SAM Map Type - in D64 switches in upper 32K RAM $8000-$feff


*/

module sam(

  input clk,
  input [15:0] Ai,

  input RWi,

  output reg [6:0] disp_offset,

  output VClk,
  input VClkRi,

  output reg [2:0] S,
  output [15:0] Zo,

  input iRW,

  output reg Q,
  output reg E

);


reg [4:0] clk_div = 0;
always @(posedge clk) begin
  clk_div <= clk_div + 5'd1;
  if (clk_div == 5'b10000) E <= ~E;
  if (clk_div == 5'b00000) Q <= ~Q;
end

assign VClk = clk_div[1];

reg page;
reg [2:0] mode_bits;
reg ty;
reg [1:0] ms, rate;

assign Zo = ty ? { page, Ai[14:0] } : Ai;


always @(posedge clk)
  if (~iRW) begin
    case (Ai)
      16'hffc0: mode_bits[0] <= 1'b0;
      16'hffc1: mode_bits[0] <= 1'b1;
      16'hffc2: mode_bits[1] <= 1'b0;
      16'hffc3: mode_bits[1] <= 1'b1;
      16'hffc4: mode_bits[2] <= 1'b0;
      16'hffc5: mode_bits[2] <= 1'b1;
      16'hffc6: disp_offset[0] <= 1'b0;
      16'hffc7: disp_offset[0] <= 1'b1;
      16'hffc8: disp_offset[1] <= 1'b0;
      16'hffc9: disp_offset[1] <= 1'b1;
      16'hffca: disp_offset[2] <= 1'b0;
      16'hffcb: disp_offset[2] <= 1'b1;
      16'hffcc: disp_offset[3] <= 1'b0;
      16'hffcd: disp_offset[3] <= 1'b1;
      16'hffce: disp_offset[4] <= 1'b0;
      16'hffcf: disp_offset[4] <= 1'b1;
      16'hffd0: disp_offset[5] <= 1'b0;
      16'hffd1: disp_offset[5] <= 1'b1;
      16'hffd2: disp_offset[6] <= 1'b0;
      16'hffd3: disp_offset[6] <= 1'b1;
      16'hffd4: page <= 1'b0;
      16'hffd5: page <= 1'b1;
      16'hffd6: rate[0] <= 1'b0;
      16'hffd7: rate[0] <= 1'b1;
      16'hffd8: rate[1] <= 1'b0;
      16'hffd9: rate[1] <= 1'b1;
      16'hffda: ms[0] <= 1'b0;
      16'hffdb: ms[0] <= 1'b1;
      16'hffdc: ms[1] <= 1'b0;
      16'hffdd: ms[1] <= 1'b1;
      16'hffde: ty <= 1'b0;
      16'hffdf: ty <= 1'b1;
    endcase
  end
  else if (VClkRi) begin
    disp_offset <= 7'd0;
    page <= 1'b0;
  end


// sel

always @*
  casez (Ai)
    16'b0???_????_????_????: S = 0; // 0000-7fff ram
    16'b1???_????_????_????: begin
      if (ty & iRW) S = 0;
      else
        casez (Ai)
          16'b100?_????_????_????: S = 1; // 8000-9fff exp rom
          16'b101?_????_????_????: S = 2; // a000-bfff bas rom
          16'b110?_????_????_????: S = 3; // c000-dfff \
          16'b1110_????_????_????: S = 3; // e000-efff |
          16'b1111_0???_????_????: S = 3; // f000-f7ff |
          16'b1111_10??_????_????: S = 3; // f800-fbff |
          16'b1111_110?_????_????: S = 3; // fc00-fdff |
          16'b1111_1110_????_????: S = 3; // fe00-feff /
          16'b1111_1111_000?_????: S = 4; // ff00-ff1f pia1
          16'b1111_1111_001?_????: S = 5; // ff20-ff3f pia2
          16'b1111_1111_010?_????: S = 6; // ff40-ff5f scs (cartridge spare select signal)
          // -- reserved FF60 - FFBF
          16'b1111_1111_110?_????: S = 7; // ffc0-ffdf SAM ctrl reg
          16'b1111_1111_111?_????: S = 2; // ffe0-ffff i/o
        endcase
    end
  endcase

endmodule
