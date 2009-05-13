module dds2(
    input                            clk,
    input                            reset,
    input                            enable,
    input [(PHASE_INC_WIDTH-1):0]    inc,
    output wire [(OUTPUT_WIDTH-1):0] out);
   
   parameter ACC_WIDTH = 1;
   parameter PHASE_INC_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;

   wire [(PHASE_INC_WIDTH-1):0] inc_value;
   assign inc_value = enable ? inc : {PHASE_INC_WIDTH{1'b0}};

   reg [(ACC_WIDTH-1):0] accumulator;
   always @(posedge clk) begin
      accumulator <= reset ? {ACC_WIDTH{1'b0}} :
                     accumulator+{{ACC_WIDTH-PHASE_INC_WIDTH{1'b0}},inc_value};
   end

   //Output is the top bits of the phase accumulator.
   assign out = accumulator[(ACC_WIDTH-1):(ACC_WIDTH-OUTPUT_WIDTH)];
endmodule