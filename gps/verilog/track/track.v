//Accumulator width.
//Max value at 16.8MHz:
//  +/-3 * 16MHz * 3 ms/accumulation = 50400 ~ 2^16
`define ACC_WIDTH 16

//C/A chipping rate phase increment
//for DDS to yeild 1.023MHz from 16.8MHz.
`define CA_RATE_INC 1021613

module Track(
    input clk,
    input reset,
    input enable, 
    input [4:0] prn,
    input [2:0] basebandInput,
    output reg [(`ACC_WIDTH-1):0] accumulator);
   //Generate C/A code clock from reference
   //clock provided by A/D.
   wire caClk;
   DDS #(.ACC_WIDTH(24),
         .PHASE_INC_WIDTH(20),
         .OUTPUT_WIDTH(1))
     ca_clock_gen(.clk(clk & enable),
                  .reset(reset),
                  .inc(20'd`CA_RATE_INC),
                  .out(caClk));

   //Generate C/A code bit for given PRN.
   wire [9:0] codeShift;
   wire       caBit;
   CAGenerator ca_gen(.clk(caClk),
                      .reset(reset),
                      .prn(prn),
                      .codeShift(codeShift),
                      .out(caBit));

   //Wipe off C/A code.
   wire [2:0] wipedInput;
   assign wipedInput[2] = basebandInput[2]^~caBit;
   assign wipedInput[1:0] = basebandInput[1:0];

   //Sign-extend value and convert to two's complement.
   wire [2:0] input2c;
   OnesExtend #(.IN_WIDTH(3),
                .OUT_WIDTH(`ACC_WIDTH))
     input_extend(.value(wipedInput),
                  .result(input2c));

   //Accumulate input value.
   always @(clk) begin
      accumulator <= reset ? 'h0 : input2c;
   end
endmodule