module dds(
    input                            clk,
    input                            reset,
    input [(PHASE_INC_WIDTH-1):0]    inc,
    output wire [(OUTPUT_WIDTH-1):0] out);
   
   parameter ACC_WIDTH = 1;
   parameter PHASE_INC_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;

   reg [ACC_WIDTH:0] accumulator;

   //Output is the top bits of the phase accumulator.
   assign out = accumulator[(ACC_WIDTH-1):(ACC_WIDTH-OUTPUT_WIDTH)];

   always @(posedge clk) begin
      //Update phase accumulator.
      accumulator <= reset ?
                     'h0 :
                     accumulator+inc;
   end
endmodule