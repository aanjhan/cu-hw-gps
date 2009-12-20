module dds(
    input                            clk,
    input                            reset,
    input                            enable,
    input [(PHASE_INC_WIDTH-1):0]    inc,
    output wire [(OUTPUT_WIDTH-1):0] out);
   
   parameter ACC_WIDTH = 1;
   parameter PHASE_INC_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;
   parameter PIPELINE = 0;
   parameter [(ACC_WIDTH-1):0] ACC_RESET_VALUE = {ACC_WIDTH{1'b0}};

   //Increment by zero to implement disable.
   wire [(PHASE_INC_WIDTH-1):0] inc_value;
   //assign inc_value = enable ? inc : {PHASE_INC_WIDTH{1'b0}};
   assign inc_value = inc & {PHASE_INC_WIDTH{enable}};

   //Zero-extend phase increment to accumulator width.
   wire [(ACC_WIDTH-1):0] inc_extended;
   assign inc_extended = {{ACC_WIDTH-PHASE_INC_WIDTH{1'b0}},inc_value};

   wire [(ACC_WIDTH-1):0] next_value;
   generate
      if(PIPELINE) begin
         wire [(ACC_WIDTH-1):0] inc_km1;
         delay #(.WIDTH(ACC_WIDTH))
           next_delay(.clk(clk),
                      .reset(reset),
                      .in(inc_extended),
                      .out(inc_km1));
         assign next_value = accumulator+inc_km1;
      end
      else begin
         assign next_value = accumulator+inc_extended;
      end
   endgenerate

   reg [(ACC_WIDTH-1):0] accumulator;
   always @(posedge clk) begin
      accumulator <= reset ? ACC_RESET_VALUE :
                     next_value;
      //accumulator <= next_value & {ACC_WIDTH{~reset}};
   end

   //Output is the top bits of the phase accumulator.
   assign out = accumulator[(ACC_WIDTH-1):(ACC_WIDTH-OUTPUT_WIDTH)];
endmodule