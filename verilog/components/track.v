`include "global.vh"

module track(
    input                           clk,
    input                           reset,
    input                           clear,
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

   wire data_available_km1;
   delay data_available_delay(.clk(clk),
                              .reset(reset),
                              .in(data_available),
                              .out(data_available_km1));

   //Accumulate input value.
   always @(posedge clk) begin
      accumulator <= reset ? {OUTPUT_WIDTH{1'b0}} :
                     data_available_km1 ? (clear ? input2c_km1 :
                                           accumulator+input2c_km1) :
                     clear ? {OUTPUT_WIDTH{1'b0}} :
                     accumulator;
   end
endmodule