module power_on_reset(
    input      clk,
    output reg reset);

   parameter WIDTH = 8;

   reg [(WIDTH-1):0] count;
   always @(posedge clk) begin
      count <= count!={WIDTH{1'b1}} ?
               count+{{(WIDTH-1){1'b0}},1'b1} :
               count;

      reset <= count!={WIDTH{1'b1}};
   end
endmodule