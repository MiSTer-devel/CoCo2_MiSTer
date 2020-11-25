
module chrrom #(
  parameter ROMFILE = "chrrom"
) (
  input clk,
  input [9:0] addr,
  output reg [7:0] dout
);

// 12 x 8bit = 12 bytes / character
reg [7:0] memory[8*64:0];
initial $readmemh(ROMFILE, memory, 0);

always @(posedge clk)
  dout <= memory[addr];

endmodule
