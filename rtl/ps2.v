
module ps2(    
  input ps2_clk, // -> from ps/2
  input ps2_dat, // -> from ps/2
  output reg [7:0] data // full byte
);

reg [3:0] counter;
reg [7:0] sr, prv;
wire brk = counter == 4'd9;

always @(negedge ps2_clk)
  if (counter == 4'd10)
    counter <= 4'd0;
  else
    counter <= counter + 4'b1;

always @(negedge ps2_clk)
  if (counter > 0 && counter < 4'd9)
    sr <= { sr[6:0], ps2_dat };

always @(posedge brk)
  if (prv == 8'hf0)
    data <= sr;
  else
    prv <= sr;

endmodule