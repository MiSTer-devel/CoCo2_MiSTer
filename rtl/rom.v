
module rom #(
  parameter ROMFILE = "rom", SIZE = 8191
) (
  input clk,
  input [12:0] addr,
  output reg [7:0] dout,
  input cs
);

reg [7:0] memory[8191:0];
initial $readmemh(ROMFILE, memory, 0, SIZE);

always @(posedge clk)
  if (~cs) dout <= memory[addr];


endmodule
