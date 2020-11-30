/*
acia.sv

Copyright 2020
Alan Steremberg - alanswx

digital emualtion of the dragon 64 serial port

This is a stub for now to get the machine running

*/


module acia (
  input clk,
  input [2:0]addr,
  output [7:0]data
  );
  

 always @(posedge clk) begin
   case (addr[1:0])
		3'd0: /* receive data */
		    data<=8'h00;
		3'd1: /* Status */
		    data<=8'h10;
		3'd2: /* Command */
		    data<=8'h02;
		3'd3:  /* Control */
		    data<=8'h00;
	endcase
end

endmodule