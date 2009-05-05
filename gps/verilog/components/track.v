//Accumulator width.
//Max value at 16.8MHz:
//  +/-3 * 16MHz * 3 ms/accumulation = 50400 ~ 2^16
`define ACC_WIDTH 16

module track(
    input       clk,
    input       clk_sample,
    input       reset,
    input [2:0] baseband_input,
    input       ca_bit,
    output reg [(`ACC_WIDTH-1):0] accumulator);

   //Wipe off C/A code.
   wire [2:0] wiped_input;
   assign wiped_input[2] = ~(baseband_input[2]^ca_bit);
   assign wiped_input[1:0] = baseband_input[1:0];

   //Sign-extend value and convert to two's complement.
   wire [(`ACC_WIDTH-1):0] input2c;
   ones_extend #(.IN_WIDTH(3),
                 .OUT_WIDTH(`ACC_WIDTH))
     input_extend(.value(wiped_input),
                  .result(input2c));

   //Accumulate input value.
   always @(negedge clk_sample) begin
      accumulator <= reset ? 'h0 : accumulator + input2c;
   end
endmodule