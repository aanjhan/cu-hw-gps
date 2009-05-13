module strobe(
    input      clk,
    input      reset,
    input      in,
    output reg out);

   reg in_km1;
   
   always @(posedge clk) begin
      in_km1 <= in;
      
      out <= reset ? 1'b0 : (in & ~in_km1);
   end
   
endmodule