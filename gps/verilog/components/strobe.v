module strobe(
    input       clk,
    input       reset,
    input       in,
    output wire out);

   reg in_km1;
   always @(posedge clk) begin
      in_km1 <= in;
   end
   
   assign out = reset ? 1'b0 : (in & ~in_km1);
   
endmodule