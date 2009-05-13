`define INPUT_RANGE INPUT_MSB:INPUT_LSB
`define INPUT_MAG INPUT_MAG_MSB:INPUT_MAG_LSB

`define ACC_RANGE ACC_MSB:ACC_LSB

module track(
    input                   clk,
    input                   reset,
    input                   data_available,
    input [`INPUT_RANGE]    baseband_input,
    input                   ca_bit,
    output reg [`ACC_RANGE] accumulator);

   `include "common_functions.vh"

   //Data input paramters.
   parameter  INPUT_WIDTH = 3;
   localparam INPUT_MSB = INPUT_WIDTH-1;
   localparam INPUT_LSB = 0;
   localparam INPUT_SIGN = INPUT_WIDTH-1;
   localparam INPUT_MAG_MSB = INPUT_SIGN-1;
   localparam INPUT_MAG_LSB = 0;
   
   //Accumulator parameters.
   //Max value at 16.8MHz:
   //  +/-3 * 16MHz * 3 ms/accumulation = 151200 ~ 2^18
   parameter  ACC_LENGTH = 3;
   localparam ACC_WIDTH = max_width(max_value(INPUT_WIDTH)*ACC_LENGTH*16800);
   localparam ACC_MSB = ACC_WIDTH-1;
   localparam ACC_LSB = 0;

   //Wipe off C/A code.
   wire [`INPUT_RANGE] wiped_input;
   assign wiped_input[INPUT_SIGN] = ~(baseband_input[INPUT_SIGN]^ca_bit);
   assign wiped_input[`INPUT_MAG] = baseband_input[`INPUT_MAG];

   //Sign-extend value and convert to two's complement.
   wire [`ACC_RANGE] input2c;
   ones_extend #(.IN_WIDTH(INPUT_WIDTH),
                 .OUT_WIDTH(ACC_WIDTH))
     input_extend(.value(wiped_input),
                  .result(input2c));

   //Accumulate input value.
   always @(posedge clk) begin
      accumulator <= reset ? 'h0 :
                     data_available ? accumulator + input2c :
                     accumulator;
   end
endmodule