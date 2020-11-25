
module uart_rx (
  input clk,
  input rx,
  output reg [7:0] dout,
  output reg done
);

reg [2:0] state;
reg [2:0] new_state;
reg [7:0] SR;
reg [2:0] SC;
reg [9:0] cycles;

parameter BCLK = 10'd434 - 1;
parameter HBCLK = 10'd217 - 1;

parameter
  IDLE   = 3'd0,
  START  = 3'd1,
  READ   = 3'd2,
  STOP   = 3'd3,
  DONE   = 3'd4;

always @(posedge clk)
  state <= new_state;

always @(posedge clk)
  case (state)
    IDLE:
      if (rx == 0) begin
        new_state <= START;
        cycles <= 0;
        SR <= 0;
        SC <= 0;
      end
    START:
      if (cycles == HBCLK) begin
        cycles <= 0;
        if (rx == 0)
          new_state <= READ;
        else
          new_state <= IDLE;
      end
      else
        cycles <= cycles + 1;
    READ:
      if (cycles == BCLK) begin
        cycles <= 0;
        SR <= { rx , SR[7:1] };
        SC <= SC + 1;
        if (SC == 3'd7)
          new_state <= STOP;
      end
      else
        cycles <= cycles + 1;
    STOP:
      if (cycles == BCLK) begin
        cycles <= 0;
        new_state <= DONE;
        done <= 1;
        dout <= SR;
      end
      else
        cycles <= cycles + 1;
    DONE: begin
      new_state <= IDLE;
      done <= 0;
    end
  endcase

endmodule
