
module ram (
  input clk,
  input [14:0] addr,
  input [7:0] din,
  input we,
  input cs,
  output reg [7:0] dout,

  // port b
  input [14:0] addr_b,
  output reg [7:0] dout_b
);

reg [7:0] memory[32767:0];

`ifdef XILINX_ISIM
  reg [14:0] ii;
  initial begin
    for (ii = 0; ii < 32767; ii = ii + 1) memory[ii] = 0;
  end
`endif

always @(posedge clk) begin
  if (~we && ~cs) memory[addr] <= din;
  dout <= memory[addr];
  dout_b <= memory[addr_b];
end

endmodule
