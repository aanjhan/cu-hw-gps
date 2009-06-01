`include "global.vh"

module track(
    input                           clk,
    input                           reset,
    input                           data_available,
    input [(INPUT_WIDTH-1):0]       baseband_input,
    input                           ca_bit,
    output reg [(OUTPUT_WIDTH-1):0] accumulator);

   parameter INPUT_WIDTH = `INPUT_WIDTH;
   localparam INPUT_SIGN = INPUT_WIDTH-1;
   localparam INPUT_MAG_MSB = INPUT_SIGN-1;
   
   parameter OUTPUT_WIDTH = `INPUT_WIDTH;

   //Wipe off C/A code.
   wire [(INPUT_WIDTH-1):0] wiped_input;
   assign wiped_input[INPUT_SIGN] = ~(baseband_input[INPUT_SIGN]^ca_bit);
   assign wiped_input[INPUT_MAG_MSB:0] = baseband_input[INPUT_MAG_MSB:0];

   //Sign-extend value and convert to two's complement.
   wire [(OUTPUT_WIDTH-1):0] input2c;
   ones_extend #(.IN_WIDTH(INPUT_WIDTH),
                 .OUT_WIDTH(OUTPUT_WIDTH))
     input_extend(.value(wiped_input),
                  .result(input2c));

   //FIXME If needed, place a delay pipe here for timing.
   //FIXME In that case, reduce ones_extend output width
   //FIXME to INPUT_WIDTH and pad sign bits in addition
   //FIXME as {{(ACC_WIDTH-INPUT_WIDTH){input2c[INPUT_WIDTH-1]}},input2c}

   //Accumulate input value.
   always @(posedge clk) begin
      accumulator <= reset ? {OUTPUT_WIDTH{1'b0}} :
                     data_available ? accumulator + input2c :
                     accumulator;
   end
endmodule