module strobe(
    input       clk,
    input       reset,
    input       in,
    output wire out);

   parameter STROBE_AFTER_RESET = 0;
   parameter RESET_ZERO = 0;
   parameter RESET_ONE = 0;
   parameter FLAG_CHANGE = 0;
   
   reg in_km1;
   always @(posedge clk) begin
      if(STROBE_AFTER_RESET)in_km1 <= reset ? ~in : in;
      else if(RESET_ZERO)in_km1 <= reset ? 1'b0 : in;
      else if(RESET_ONE)in_km1 <= reset ? 1'b1 : in;
      else in_km1 <= in;
   end
   
   assign out = reset ? 1'b0 :
                FLAG_CHANGE ? in!=in_km1 :
                (in & ~in_km1);

endmodule
