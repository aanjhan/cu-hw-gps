module delay_en_1(
    input                     clk,
    input                     reset,
    input                     enable,
    input [(WIDTH-1):0]       in,
    output wire [(WIDTH-1):0] out);

   parameter WIDTH = 1;

   reg [(WIDTH-1):0] in_km1;

   always @(posedge clk) begin
      in_km1 <= reset ? {WIDTH{1'b0}} :
                enable ? in :
                in_km1;
   end

   assign out = in_km1;
   
endmodule