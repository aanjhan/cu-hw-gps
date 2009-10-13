`include "global.vh"
`include "dll.vh"
`include "channel__dll.vh"

`define DEBUG
`include "debug.vh"

module dll(
    input                           clk,
    input                           reset,
    //Control interface.
    input                           start,
    input [`CHANNEL_ID_RANGE]       tag,
    //Channel tracking values.
    input [`IQ_RANGE]               iq_early,
    input [`IQ_RANGE]               iq_late,
    //Results interface.
    output wire                     result_ready,
    output wire [`CHANNEL_ID_RANGE] result_tag,
    output wire [`DLL_DPHI_RANGE]   delta_phase_increment);

   //Phase increment offset calculation:
   //  eml=iq_early-iq_late
   //  epl=iq_early+iq_late
   //  tau_prime=eml/epl*((2-CHIPS_EML)/2)
   //  tau_prime_up=tau_prime*F_S/F_CA
   //              =eml/epl*((2-CHIPS_EML)*F_S/F_CA/2)
   //  dphi=tau_prime_up*2^ca_acc_width*HNUM
   //      =eml/epl*(2^ca_acc_width*(2-chips_eml)*f_s/f_ca/2*HNUM)
   //      =eml/epl*C
   //      =(eml/epl*K)>>kshift
   //  C=2^ca_acc_width*HNUM*(2-chips_eml)*f_s/f_ca/2
   //  K=C<<shift (fixed-point)
   //Note: the resulting phase increment does not include Doppler
   //      aiding, which is necessary for long-term tracking.
   //
   //Calculation sequence:
   //  -Calculation of eml and epl values.
   //  -"Smart" truncation of values for reduced circuit complexity.
   //  -Calculation of eml*K.
   //  -Division of result by epl.
   //  -Fixed-point shift to final result.

   //Generate DLL clock from system clock.
   reg [`DLL_CLK_RANGE] dll_clk_count;
   reg clk_dll;
   reg div_edge;
   always @(posedge clk) begin
      dll_clk_count <= reset ? `DLL_CLK_WIDTH'd`DLL_CLK_MAX :
                       dll_clk_count==`DLL_CLK_MAX ? `DLL_CLK_WIDTH'h0 :
                       dll_clk_count+`DLL_CLK_WIDTH'h1;

      clk_dll <= reset ? 1'b0 :
                 dll_clk_count==`DLL_CLK_WIDTH'd`DLL_CLK_MAX ? ~clk_dll :
                 clk_dll;

      div_edge <= !reset && dll_clk_count==`DLL_CLK_WIDTH'd`DLL_CLK_MAX && !clk_dll ? 1'b1 : 1'b0;
   end // always @ (posedge clk)

   //Zero-pad IQ values if necessary to meet sum width.
   wire [`DLL_OP_PRE_RANGE] iq_early_padded;
   assign iq_early_padded = {{(`DLL_OP_PRE_WIDTH-`IQ_WIDTH){1'b0}},iq_early[`IQ_RANGE]};
   
   wire [`DLL_OP_PRE_RANGE] iq_late_padded;
   assign iq_late_padded = {{(`DLL_OP_PRE_WIDTH-`IQ_WIDTH){1'b0}},iq_late[`IQ_RANGE]};

   //Compute the sum and difference of
   //the early and late IQ values.
   wire [`DLL_OP_PRE_RANGE] iq_sum_pre_trunc;
   assign iq_sum_pre_trunc = iq_early_padded+iq_late_padded;
   
   wire [`DLL_OP_PRE_RANGE] iq_diff_pre_trunc;
   assign iq_diff_pre_trunc = iq_early_padded-iq_late_padded;

   //Take the absolute value to avoid signed computation.
   //The sign bit is important for shift direction so
   //it is maintained to be supplied with the result.
   wire [`DLL_OP_PRE_RANGE] iq_diff_abs;
   abs #(.WIDTH(`DLL_OP_PRE_WIDTH))
     diff_abs(.in(iq_diff_pre_trunc),
              .out(iq_diff_abs[(`DLL_OP_PRE_WIDTH-2):0]));
   assign iq_diff_abs[`DLL_OP_PRE_WIDTH-1]=1'b0;

   //Pipe value for timing.
   `PRESERVE reg [`DLL_OP_PRE_RANGE] iq_sum_pre_km1;
   `PRESERVE reg [`DLL_OP_PRE_RANGE] iq_diff_pre_km1;
   always @(posedge clk) begin
      iq_sum_pre_km1 <= div_edge ? iq_sum_pre_trunc : iq_sum_pre_km1;
      iq_diff_pre_km1 <= div_edge ? iq_diff_abs : iq_diff_pre_km1;
   end

   //Pipe the tag and shift direction along
   //until calculation is complete.
   //FIXME Edge-triggered flops instead of long delay path?
   `KEEP wire shift_direction;
   delay #(.DELAY(`TOTAL_DELAY_LENGTH))
     shift_direction_delay(.clk(clk),
                           .reset(reset),
                           .in(iq_diff_pre_trunc[`DLL_OP_PRE_WIDTH-1]),
                           .out(shift_direction));
   
   delay #(.WIDTH(`CHANNEL_ID_WIDTH),
           .DELAY(`TOTAL_DELAY_LENGTH))
     tag_delay(.clk(clk),
               .reset(reset),
               .in(tag),
               .out(result_tag));

   wire start_km1;
   delay start_delay(.clk(clk),
                     .reset(reset),
                     .in(start),
                     .out(start_km1));
   
   delay #(.DELAY(`TOTAL_DELAY_LENGTH))
     result_ready_delay(.clk(clk),
                        .reset(reset),
                        .in(div_edge && start_km1),
                        .out(result_ready));

   //Truncate operands to specified width, starting
   //at the most significant bit in the larger of
   //the two operand values.
   //Note: the priority encoders take 2 cycles to complete.
   `KEEP wire [`DLL_OP_INDEX_RANGE] iq_sum_index;
   dll_priority_enc sum_priority(.clk(clk),
                                 .in(iq_sum_pre_km1),
                                 .out(iq_sum_index));
   
   `KEEP wire [`DLL_OP_INDEX_RANGE] iq_diff_index;
   dll_priority_enc diff_priority(.clk(clk),
                                  .in(iq_diff_pre_km1),
                                  .out(iq_diff_index));
   
   `KEEP wire [`DLL_OP_INDEX_RANGE] iq_index;
   assign iq_index = iq_sum_index>iq_diff_index ? iq_sum_index : iq_diff_index;

   reg [`DLL_OP_INDEX_RANGE] iq_index_km1;
   always @(posedge clk) begin
      iq_index_km1 <= iq_index;
   end

   `KEEP wire div_edge_km4;
   delay #(.DELAY(4))
     div_edge_delay_1(.clk(clk),
                      .reset(reset),
                      .in(div_edge),
                      .out(div_edge_km4));

   //Note: assumption made that *_pre_km1 values are
   //stable for at least three cycles because of divided
   //DLL clock edge.
   wire [`DLL_OP_RANGE] iq_sum;
   dll_truncate #(.INDEX_WIDTH(`DLL_OP_INDEX_WIDTH),
                  .INPUT_WIDTH(`DLL_OP_PRE_WIDTH),
                  .OUTPUT_WIDTH(`DLL_OP_WIDTH))
     sum_trunc(.index(iq_index_km1),
               .in(iq_sum_pre_km1),
               .out(iq_sum));
   
   wire [`DLL_OP_RANGE] iq_diff;
   dll_truncate #(.INDEX_WIDTH(`DLL_OP_INDEX_WIDTH),
                  .INPUT_WIDTH(`DLL_OP_PRE_WIDTH),
                  .OUTPUT_WIDTH(`DLL_OP_WIDTH))
     diff_trunc(.index(iq_index_km1),
                .in(iq_diff_pre_km1),
                .out(iq_diff));

   //Flop the sum and difference values after
   //truncation when a new operation is started.
   `PRESERVE reg [`DLL_OP_RANGE] iq_sum_km1;
   `PRESERVE reg [`DLL_OP_RANGE] iq_diff_km1;
   always @(posedge clk) begin
      iq_sum_km1 <= div_edge_km4 ? iq_sum : iq_sum_km1;
      iq_diff_km1 <= div_edge_km4 ? iq_diff : iq_diff_km1;
   end

   //Perform multiplication div_edge: M=(e-l)*K.
   wire [`DLL_OP_WIDTH+`DLL_SCALE_WIDTH-1:0] mult_output;
   dll_multiplier #(.INPUT_A_WIDTH(`DLL_OP_WIDTH),
                    .INPUT_B_WIDTH(`DLL_SCALE_WIDTH))
     mult(.clock(clk),
          .dataa(iq_diff_km1),
          .datab(`DLL_SCALE),
          .result(mult_output));
   
   `KEEP wire [`DLL_MULT_OUTPUT_RANGE] mult_result;
   assign mult_result = mult_output[`DLL_MULT_OUTPUT_RANGE];

   `KEEP wire div_edge_km7;
   delay #(.DELAY(3))
     div_edge_delay_2(.clk(clk),
                      .reset(reset),
                      .in(div_edge_km4),
                      .out(div_edge_km7));

   //Flop the multiplication result and sum values
   //for setup for division stage.
   //Note: assumption made that iq_sum_km1 value is
   //stable for at least three cycles because of divided
   //DLL clock edge.
   //Note: it is assumed that there will not be another
   //edge (value update) for at least `DLL_DIV_SETUP cycles
   //to maintain setup time for the divider.
   `PRESERVE reg [`DLL_OP_RANGE] iq_sum_km4;
   `PRESERVE reg [`DLL_MULT_OUTPUT_RANGE] mult_result_km1;
   always @(posedge clk) begin
      iq_sum_km4 <= div_edge_km7 ? iq_sum_km1 : iq_sum_km4;
      mult_result_km1 <= div_edge_km7 ? mult_result : mult_result_km1;
   end


   `KEEP wire div_edge_kmn;
   delay #(.DELAY(`DLL_DIV_SETUP))
     div_edge_delay_3(.clk(clk),
                      .reset(reset),
                      .in(div_edge_km7),
                      .out(div_edge_kmn));

   //Delay division clock by cycles required for pre-calculation
   //and setup time.
   `KEEP wire clk_dll_kmn;
   delay #(.DELAY(`DIV_CLOCK_DELAY))
     div_clk_delay(.clk(clk),
                   .reset(reset),
                   .in(clk_dll),
                   .out(clk_dll_kmn));
   
   //Perform division div_edge: M/(e+l).
   `KEEP wire [`DLL_MULT_OUTPUT_RANGE] quo;
   wire [`DLL_OP_RANGE] rem;
   dll_divider #(.NUM_WIDTH(`DLL_MULT_OUTPUT_WIDTH),
                 .DEN_WIDTH(`DLL_OP_WIDTH))
     div(.clock(clk_dll_kmn),
         .numer(mult_result_km1),
         .denom(iq_sum_km4),
         .quotient(quo),
         .remain(rem));

   //Shift division result to produce final value.
   assign delta_phase_increment = shift_direction==`DLL_DPHI_DIR_FWD ?
                                  quo>>`DLL_SCALE_SHIFT :
                                  -(quo>>`DLL_SCALE_SHIFT);
endmodule