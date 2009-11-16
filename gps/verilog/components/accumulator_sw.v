`include "global.vh"

module accumulator_sw(
    input                           clk,
    input                           reset,
    input                           clear,
    input [(INPUT_WIDTH-1):0]       baseband_input,
    input                           ca_bit,
    //Accumulator state.
    input [(OUTPUT_WIDTH-1):0]      accumulator_in,
    output reg [(OUTPUT_WIDTH-1):0] accumulator_out);

   parameter INPUT_WIDTH = `INPUT_WIDTH;
   localparam INPUT_SIGN = INPUT_WIDTH-1;
   localparam INPUT_MAG_MSB = INPUT_SIGN-1;
   
   parameter OUTPUT_WIDTH = `INPUT_WIDTH;

   //Wipe off C/A code.
   wire [(INPUT_WIDTH-1):0] wiped_input;
   assign wiped_input[INPUT_SIGN] = baseband_input[INPUT_SIGN]^(~ca_bit);
   assign wiped_input[INPUT_MAG_MSB:0] = baseband_input[INPUT_MAG_MSB:0];

   //Sign-extend value and convert to two's complement.
   wire [(OUTPUT_WIDTH-1):0] input2c;
   ones_extend #(.IN_WIDTH(INPUT_WIDTH),
                 .OUT_WIDTH(OUTPUT_WIDTH))
     input_extend(.value(wiped_input),
                  .result(input2c));

   //Pipe to meet timing.
   wire [(OUTPUT_WIDTH-1):0] input2c_km1;
   delay #(.WIDTH(OUTPUT_WIDTH))
     value_delay(.clk(clk),
                 .reset(reset),
                 .in(input2c),
                 .out(input2c_km1));

   //Accumulate input value.
   always @(*) begin
      accumulator_out <= reset ? {OUTPUT_WIDTH{1'b0}} :
                         clear ? input2c_km1 :
                         accumulator_in+input2c_km1;
   end
endmodule