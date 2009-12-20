module synchronizer(
    input                     clk,
    input [(WIDTH-1):0]       in,
    output wire [(WIDTH-1):0] out);

   parameter WIDTH = 1;

   reg [(WIDTH-1):0] sync[1:2];
   always @(posedge clk) begin
      sync[1] <= in;
      sync[2] <= sync[1];
   end

   assign out = sync[2];
   
endmodule