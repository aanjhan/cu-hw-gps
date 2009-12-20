module delay_en(
    input                     clk,
    input                     reset,
    input                     enable,
    input [(WIDTH-1):0]       in,
    output wire [(WIDTH-1):0] out);

   parameter WIDTH = 1;
   parameter DELAY = 1;

   wire [(WIDTH-1):0] in_km[0:DELAY];

   assign in_km[0] = in;

   genvar i;
   generate
      for(i=1;i<=DELAY;i=i+1) begin:delay_gen
         delay_en_1 #(.WIDTH(WIDTH))
           d(.clk(clk),
             .reset(reset),
             .enable(enable),
             .in(in_km[i-1]),
             .out(in_km[i]));
      end
   endgenerate

   assign out = in_km[DELAY];
   
endmodule