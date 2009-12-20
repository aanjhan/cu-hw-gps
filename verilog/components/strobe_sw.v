module strobe_sw(
    input       clk,
    input       reset,
    input       in,
    output wire out,
    //Strobe state.
    input       hist_in,
    output reg  hist_out);

   parameter STROBE_AFTER_RESET = 0;
   parameter RESET_ZERO = 0;
   parameter RESET_ONE = 0;
   parameter FLAG_CHANGE = 0;
   
   always @(*) begin
      if(STROBE_AFTER_RESET)hist_out <= reset ? ~in : in;
      else if(RESET_ZERO)hist_out <= reset ? 1'b0 : in;
      else if(RESET_ONE)hist_out <= reset ? 1'b1 : in;
      else hist_out <= in;
   end
   
   assign out = reset ? 1'b0 :
                FLAG_CHANGE ? in!=hist_in :
                (in & ~hist_in);

endmodule
