//Accumulator width.
//Max value at 16.8MHz:
//  +/-3 * 16MHz * 3 ms/accumulation = 50400 ~ 2^16
`define ACC_WIDTH 16

module track(
    input       clk,
    input       clk_sample,
    input       reset,
    input [2:0] basebandInput,
    input       ca_bit,
    output reg [(`ACC_WIDTH-1):0] accumulator);

   //Wipe off C/A code.
   wire [2:0] wipedInput;
   assign wipedInput[2] = ~(basebandInput[2]^ca_bit);
   assign wipedInput[1:0] = basebandInput[1:0];

   //Sign-extend value and convert to two's complement.
   wire [(`ACC_WIDTH-1):0] input2c;
   OnesExtend #(.IN_WIDTH(3),
                .OUT_WIDTH(`ACC_WIDTH))
     input_extend(.value(wipedInput),
                  .result(input2c));

   //Accumulate input value.
   always @(negedge clk_sample) begin
      accumulator <= reset ? 'h0 : accumulator + input2c;
   end
endmodule