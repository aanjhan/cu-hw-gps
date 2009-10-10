`include "global.vh"
`include "dll.vh"
`include "channel__dll.vh"

`define DEBUG
`include "debug.vh"

module dll(
    input                           clk,
    input                           global_reset,
    input [`CHANNEL_ID_RANGE]       tag,
    input [`I2Q2_RANGE]             i2q2_early,
    input [`I2Q2_RANGE]             i2q2_late,
    output wire [`CHANNEL_ID_RANGE] result_tag,
    output wire                     result_ready,                     
    output wire                     shift_direction,
    output wire [`DLL_SHIFT_RANGE]  shift_amount);

   //Shift amount calculation:
   //  eml=i2q2_early-i2q2_late
   //  epl=i2q2_early+i2q2_late
   //  tau_prime=eml/epl*((2-CHIPS_EML)/2)
   //  tau_prime_up=tau_prime*F_S/F_CA
   //              =eml/epl*((2-CHIPS_EML)*F_S/F_CA/2)
   //              =eml/epl*C
   //              =(eml/epl*K)>>shift
   //  C=((2-CHIPS_EML)*F_S/F_CA/2)
   //  K=C<<shift (fixed-point)
   //
   //Calculation sequence:
   //  -Calculation of eml and epl values.
   //  -"Smart" truncation of values for reduced circuit complexity.
   //  -Calculation of eml*K.
   //  -Division of result by epl.
   //  -Fixed-point shift to final result.
   //
   //Sequence cycle times:
   //  --Operand (eml,epl) calculation = 1 cycle
   //  --Priority encoder = 3 cycles
   //  --Truncation = 1 cycle
   //  --Multiplication = 2 cycles
   //  --Division setup = `DLL_DIV_SETUP cycles
   //  --Division = 20 cycles
   localparam DIV_CLOCK_DELAY=7+`DLL_DIV_SETUP;
   localparam TOTAL_DELAY_LENGTH=10+DIV_CLOCK_DELAY;

   //Generate DLL clock from system clock.
   reg [`DLL_CLK_RANGE] dll_clk_count;
   reg clk_dll;
   reg div_edge;
   always @(posedge clk) begin
      dll_clk_count <= global_reset ? `DLL_CLK_MAX :
                       dll_clk_count==`DLL_CLK_MAX ? `DLL_CLK_WIDTH'h0 :
                       dll_clk_count+`DLL_CLK_WIDTH'h1;

      clk_dll <= global_reset ? 1'b0 :
                 dll_clk_count==`DLL_CLK_MAX ? ~clk_dll :
                 clk_dll;

      div_edge <= dll_clk_count==`DLL_CLK_MAX && !clk_dll ? 1'b1 : 1'b0;
   end // always @ (posedge clk)

   //Zero-pad I2Q2 values if necessary to meet sum width.
   wire [`DLL_OP_PRE_RANGE] i2q2_early_padded;
   assign i2q2_early_padded = {{(`DLL_OP_PRE_WIDTH-`I2Q2_WIDTH_TRACK){1'b0}},i2q2_early[`I2Q2_RANGE_TRACK]};
   
   wire [`DLL_OP_PRE_RANGE] i2q2_late_padded;
   assign i2q2_late_padded = {{(`DLL_OP_PRE_WIDTH-`I2Q2_WIDTH_TRACK){1'b0}},i2q2_late[`I2Q2_RANGE_TRACK]};

   //Compute the sum and difference of
   //the early and late I2Q2 values.
   wire [`DLL_OP_PRE_RANGE] i2q2_sum_pre_trunc;
   assign i2q2_sum_pre_trunc = i2q2_early_padded+i2q2_late_padded;
   
   wire [`DLL_OP_PRE_RANGE] i2q2_diff_pre_trunc;
   assign i2q2_diff_pre_trunc = i2q2_early_padded-i2q2_late_padded;

   //Take the absolute value to avoid signed computation.
   //The sign bit is important for shift direction so
   //it is maintained to be supplied with the result.
   wire [`DLL_OP_PRE_RANGE] i2q2_diff_abs;
   abs #(.WIDTH(`DLL_OP_PRE_WIDTH))
     diff_abs(.in(i2q2_diff_pre_trunc),
              .out(i2q2_diff_abs[(`DLL_OP_PRE_WIDTH-2):0]));
   assign i2q2_diff_abs[`DLL_OP_PRE_WIDTH-1]=1'b0;

   //Pipe value for timing.
   `PRESERVE reg [`DLL_OP_PRE_RANGE] i2q2_sum_pre_km1;
   `PRESERVE reg [`DLL_OP_PRE_RANGE] i2q2_diff_pre_km1;
   always @(posedge clk) begin
      i2q2_sum_pre_km1 <= div_edge ? i2q2_sum_pre_trunc : i2q2_sum_pre_km1;
      i2q2_diff_pre_km1 <= div_edge ? i2q2_diff_abs : i2q2_diff_pre_km1;
   end

   //Pipe the tag and shift direction along
   //until calculation is complete.
   //FIXME Edge-triggered flops instead of long delay path?
   delay #(.DELAY(TOTAL_DELAY_LENGTH))
     shift_direction_delay(.clk(clk),
                           .reset(global_reset),
                           .in(i2q2_diff_pre_trunc[`DLL_OP_PRE_WIDTH-1]),
                           .out(shift_direction));
   
   delay #(.WIDTH(`CHANNEL_ID_WIDTH),
           .DELAY(TOTAL_DELAY_LENGTH))
     tag_delay(.clk(clk),
               .reset(global_reset),
               .in(tag),
               .out(result_tag));

   //Truncate operands to specified width, starting
   //at the most significant bit in the larger of
   //the two operand values.
   //Note: the priority encoders take 2 cycles to complete.
   `KEEP wire [`DLL_OP_INDEX_RANGE] i2q2_sum_index;
   dll_priority_enc sum_priority(.clk(clk),
                                 .in(i2q2_sum_pre_km1),
                                 .out(i2q2_sum_index));
   
   `KEEP wire [`DLL_OP_INDEX_RANGE] i2q2_diff_index;
   dll_priority_enc diff_priority(.clk(clk),
                                  .in(i2q2_diff_pre_km1),
                                  .out(i2q2_diff_index));
   
   `KEEP wire [`DLL_OP_INDEX_RANGE] i2q2_index;
   assign i2q2_index = i2q2_sum_index>i2q2_diff_index ? i2q2_sum_index : i2q2_diff_index;

   reg [`DLL_OP_INDEX_RANGE] i2q2_index_km1;
   always @(posedge clk) begin
      i2q2_index_km1 <= i2q2_index;
   end

   `KEEP wire div_edge_km4;
   delay #(.DELAY(4))
     div_edge_delay_1(.clk(clk),
                      .reset(global_reset),
                      .in(div_edge),
                      .out(div_edge_km4));

   //Note: assumption made that *_pre_km1 values are
   //stable for at least three cycles because of divided
   //DLL clock edge.
   wire [`DLL_OP_RANGE] i2q2_sum;
   dll_truncate sum_trunc(.index(i2q2_index_km1),
                          .in(i2q2_sum_pre_km1),
                          .out(i2q2_sum));
   
   wire [`DLL_OP_RANGE] i2q2_diff;
   dll_truncate diff_trunc(.index(i2q2_index_km1),
                           .in(i2q2_diff_pre_km1),
                           .out(i2q2_diff));

   //Flop the sum and difference values after
   //truncation when a new operation is started.
   `PRESERVE reg [`DLL_OP_RANGE] i2q2_sum_km1;
   `PRESERVE reg [`DLL_OP_RANGE] i2q2_diff_km1;
   always @(posedge clk) begin
      i2q2_sum_km1 <= div_edge_km4 ? i2q2_sum : i2q2_sum_km1;
      i2q2_diff_km1 <= div_edge_km4 ? i2q2_diff : i2q2_diff_km1;
   end

   //Perform multiplication div_edge: M=(e-l)*K.
   `KEEP wire [`DLL_MULT_OUTPUT_RANGE] mult_result;
   multiplier mult(.clock(clk),
                   .dataa(i2q2_diff_km1),
                   .datab(`DLL_SCALE),
                   .result(mult_result));

   `KEEP wire div_edge_km7;
   delay #(.DELAY(3))
     div_edge_delay_2(.clk(clk),
                      .reset(global_reset),
                      .in(div_edge_km4),
                      .out(div_edge_km7));

   //Flop the multiplication result and sum values
   //for setup for division stage.
   //Note: assumption made that i2q2_sum_km1 value is
   //stable for at least three cycles because of divided
   //DLL clock edge.
   //Note: it is assumed that there will not be another
   //edge (value update) for at least `DLL_DIV_SETUP cycles
   //to maintain setup time for the divider.
   `PRESERVE reg [`DLL_OP_RANGE] i2q2_sum_km4;
   `PRESERVE reg [`DLL_MULT_OUTPUT_RANGE] mult_result_km1;
   always @(posedge clk) begin
      i2q2_sum_km4 <= div_edge_km7 ? i2q2_sum_km1 : i2q2_sum_km4;
      mult_result_km1 <= div_edge_km7 ? mult_result : mult_result_km1;
   end


   `KEEP wire div_edge_kmn;
   delay #(.DELAY(`DLL_DIV_SETUP))
     div_edge_delay_3(.clk(clk),
                      .reset(global_reset),
                      .in(div_edge_km7),
                      .out(div_edge_kmn));

   //Delay division clock by cycles required for pre-calculation
   //and setup time.
   `KEEP wire clk_dll_kmn;
   delay #(.DELAY(DIV_CLOCK_DELAY))
     div_clk_delay(.clk(clk),
                   .reset(global_reset),
                   .in(clk_dll),
                   .out(clk_dll_kmn));
   
   //Perform division div_edge: M/(e+l).
   `KEEP wire [`DLL_MULT_OUTPUT_RANGE] quo;
   wire [`DLL_OP_RANGE] rem;
   divider div(.clock(clk_dll_kmn),
               .numer(mult_result_km1),
               .denom(i2q2_sum_km4),
               .quotient(quo),
               .remain(rem));

   //Strobe result ready signal on divider clock edge.
   strobe result_strobe(.clk(clk),
                        .reset(global_reset),
                        .in(clk_dll_kmn),
                        .out(result_ready));

   //Shift division result to produce final value.
   assign shift_amount = quo>>`DLL_SCALE_SHIFT;
endmodule