`include "global.vh"
`include "ca_upsampler.vh"

module track(
    input                   clk,
    input                   reset,
    input                   data_available,
    input [`INPUT_RANGE]    baseband_input,
    input                   ca_bit,
    output reg [`ACC_RANGE] accumulator);

   //Wipe off C/A code.
   wire [`INPUT_RANGE] wiped_input;
   assign wiped_input[`INPUT_SIGN] = ~(baseband_input[`INPUT_SIGN]^ca_bit);
   assign wiped_input[`INPUT_MAG] = baseband_input[`INPUT_MAG];

   //Sign-extend value and convert to two's complement.
   wire [`ACC_RANGE] input2c;
   ones_extend #(.IN_WIDTH(`INPUT_WIDTH),
                 .OUT_WIDTH(`ACC_WIDTH))
     input_extend(.value(wiped_input),
                  .result(input2c));

   //FIXME If needed, place a delay pipe here for timing.
   //FIXME In that case, reduce ones_extend output width
   //FIXME to INPUT_WIDTH and pad sign bits in addition
   //FIXME as {{(ACC_WIDTH-INPUT_WIDTH){input2c[INPUT_WIDTH-1]}},input2c}

   //Accumulate input value.
   always @(posedge clk) begin
      accumulator <= reset ? {`ACC_WIDTH{1'b0}} :
                     data_available ? accumulator + input2c :
                     accumulator;
   end
endmodule