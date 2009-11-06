`include "global.vh"
`include "tracking_loops.vh"
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
    output wire                     starting,
    //Channel tracking values.
    input [`IQ_RANGE]               iq_early,
    input [`IQ_RANGE]               iq_late,
    //Updated Doppler shift.
    input                           w_df_ready,
    input [`W_DF_RANGE]             w_df_kp1,
    //Results interface.
    output reg                      result_ready,
    output wire [`CHANNEL_ID_RANGE] result_tag,
    output reg [`DLL_TAU_RANGE]     tau_prime,
    output reg [`DLL_DPHI_RANGE]    ca_dphi);

   //Phase increment offset calculation:
   //  epl=(iq-early+iq_late)
   //  div_result=(eml<<DLL_SHIFT)/epl
   //FIXME Instead of shifting by DLL_SHIFT, just reduce
   //FIXME truncation amount on eml by DLL_SHIFT to save
   //FIXME on accuracy?
   //  
   //  tau_prime=(iq-early-iq_late)/(iq-early+iq_late)*(2-CHIPS_EML)/2
   //           =eml/epl*((2-CHIPS_EML)/2)
   //  tau_prime_up=tau_prime*F_S/F_CA
   //              =eml/epl*((2-CHIPS_EML)*F_S/F_CA/2)
   //              =eml/epl*A
   //              =(eml/epl*A_FIX)>>DLL_A_SHIFT
   //              =(dll_result*A_FIX)>>(DLL_SHIFT+DLL_A_SHIFT)
   //  A=(2-CHIPS_EML)*F_S/F_CA/2
   //  A_FIX=round(A*2^DLL_A_SHIFT)
   //  
   //  dphi=tau_prime_up*2^CA_ACC_WIDTH*HNUM
   //      =eml/epl*(A*2^CA_ACC_WIDTH*HNUM)
   //      =eml/epl*B
   //      =(div_result*B_FIX)>>(DLL_SHIFT+DLL_B_SHIFT)
   //  B=A*2^CA_ACC_WIDTH*HNUM
   //  B_FIX=round(B*2^DLL_B_SHIFT)
   //
   //Note: the resulting phase increment does not include Doppler
   //      aiding, which is necessary for long-term tracking.
   //
   //Calculation sequence:
   //  -Calculation of eml and epl values.
   //  -"Smart" truncation of values for reduced circuit complexity.
   //  -Calculation of division result.
   //  -Computation of tau_prime and ca_dphi.

   /////////////////////////
   // DLL Clock Generation
   /////////////////////////

   //Generate DLL clock from system clock.
   //Note: clk_dll is forced to keep for timing constraints.
   reg [`DLL_CLK_RANGE] dll_clk_count;
   (* preserve *) reg clk_dll;
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

   //////////////////////////////
   // Sum/Difference Calculation
   //////////////////////////////

   //Zero-pad IQ values if necessary to meet sum width.
   wire [`DLL_OP_PRE_RANGE] iq_early_padded;
   assign iq_early_padded = {{(`DLL_OP_PRE_WIDTH-`IQ_WIDTH){1'b0}},iq_early[`IQ_RANGE]};
   
   wire [`DLL_OP_PRE_RANGE] iq_late_padded;
   assign iq_late_padded = {{(`DLL_OP_PRE_WIDTH-`IQ_WIDTH){1'b0}},iq_late[`IQ_RANGE]};

   //Compute the sum and difference of
   //the early and late IQ values.
   wire [`DLL_OP_PRE_RANGE] iq_sum_pre_trunc;
   assign iq_sum_pre_trunc = iq_early_padded+iq_late_padded;

   //FIXME This subtraction and subsequent absolute value
   //FIXME is taking too long. Pipeline an extra time?
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

   //Assert starting back to the top level
   //when incoming values are no longer needed.
   assign starting = div_edge && start;

   //Pipe values for timing.
   `PRESERVE reg [`DLL_OP_PRE_RANGE] iq_sum_pre_post_sum;
   `PRESERVE reg [`DLL_OP_PRE_RANGE] iq_diff_pre_post_sum;
   
   reg [`CHANNEL_ID_RANGE] tag_post_sum;
   reg                     sign_post_sum;
   reg                     start_post_sum;
   always @(posedge clk) begin
      if(div_edge) begin
         iq_sum_pre_post_sum <= iq_sum_pre_trunc;
         iq_diff_pre_post_sum <= iq_diff_abs;
      
         tag_post_sum <= tag;
         sign_post_sum <= iq_diff_pre_trunc[`DLL_OP_PRE_WIDTH-1];
         start_post_sum <= start;
      end
   end

   ////////////////////
   // Smart-Truncation
   ////////////////////

   //Truncate operands to specified width, starting
   //at the most significant bit in the larger of
   //the two operand values.

   //First, use priority encoders to determine MSB of
   //the greater of the two operands.
   //Note: the priority encoders take 2 cycles to complete.
   `KEEP wire [`DLL_OP_INDEX_RANGE] iq_sum_index;
   dll_priority_enc sum_priority(.clk(clk),
                                 .in(iq_sum_pre_post_sum),
                                 .out(iq_sum_index));
   
   `KEEP wire [`DLL_OP_INDEX_RANGE] iq_diff_index;
   dll_priority_enc diff_priority(.clk(clk),
                                  .in(iq_diff_pre_post_sum),
                                  .out(iq_diff_index));
   
   `KEEP wire [`DLL_OP_INDEX_RANGE] iq_index_val;
   assign iq_index_val = iq_sum_index>iq_diff_index ? iq_sum_index : iq_diff_index;

   `KEEP wire div_edge_km3;
   delay #(.DELAY(3))
     div_edge_delay_3(.clk(clk),
                      .reset(reset),
                      .in(div_edge),
                      .out(div_edge_km3));

   //Pipe index to truncators for timing.
   reg [`DLL_OP_INDEX_RANGE] iq_index;
   always @(posedge clk) begin
      iq_index <= div_edge_km3 ? iq_index_val : iq_index;
   end

   //Next truncate the input values to the operand width,
   //keeping the MSB of the greater value at the top.
   wire [`DLL_OP_RANGE] iq_sum;
   dll_truncate #(.INDEX_WIDTH(`DLL_OP_INDEX_WIDTH),
                  .INPUT_WIDTH(`DLL_OP_PRE_WIDTH),
                  .OUTPUT_WIDTH(`DLL_OP_WIDTH))
     sum_trunc(.index(iq_index),
               .in(iq_sum_pre_post_sum),
               .out(iq_sum));
   
   wire [`DLL_OP_RANGE] iq_diff;
   dll_truncate #(.INDEX_WIDTH(`DLL_OP_INDEX_WIDTH),
                  .INPUT_WIDTH(`DLL_OP_PRE_WIDTH),
                  .OUTPUT_WIDTH(`DLL_OP_WIDTH))
     diff_trunc(.index(iq_index),
                .in(iq_diff_pre_post_sum),
                .out(iq_diff));

   `KEEP wire trunc_complete;
   delay trunc_complete_delay(.clk(clk),
                              .reset(reset),
                              .in(div_edge_km3),
                              .out(trunc_complete));

   //Pipe sum and difference values after truncation
   //to synchronize pipeline with divider.
   //Note: This assumes that the truncation finishes
   //      within DLL_DIV_SETUP cycles.
   `PRESERVE reg [`DLL_OP_RANGE] iq_sum_post_trunc;
   `PRESERVE reg [`DLL_OP_RANGE] iq_diff_post_trunc;
   
   reg [`CHANNEL_ID_RANGE] tag_post_setup;
   reg                     sign_post_setup;
   reg                     start_post_setup;
   
   `KEEP wire div_edge_setup;
   always @(posedge clk) begin
      if(trunc_complete) begin
         iq_sum_post_trunc <= iq_sum;
         iq_diff_post_trunc <= iq_diff;
      
         tag_post_setup <= tag_post_sum;
         sign_post_setup <= sign_post_sum;
         start_post_setup <= start_post_sum;
      end
   end

   /////////////////////////
   // Fixed-Point Division
   /////////////////////////

   //Delay division clock to establish setup time.
   //FIXME Delay should be (SETUP+4)%CLOCK_DIV.
   (* keep *) wire clk_dll_kmn;
   delay #(.DELAY(`DLL_DIV_SETUP+4))
     div_clk_delay(.clk(clk),
                   .reset(reset),
                   .in(clk_dll),
                   .out(clk_dll_kmn));

   //Post-setup division clock edge.
   strobe div_edge_setup_strobe(.clk(clk),
                                .reset(reset),
                                .in(clk_dll_kmn),
                                .out(div_edge_setup));
   
   //Perform division: (eml<<DLL_SHIFT)/epl.
   //FIXME Move shift to truncation reduction? See above.
   `KEEP wire [`DLL_DIV_NUM_RANGE] quo;
   wire [`DLL_OP_RANGE] rem;
   dll_divider #(.NUM_WIDTH(`DLL_DIV_NUM_WIDTH),
                 .DEN_WIDTH(`DLL_OP_WIDTH))
     div(.clock(clk_dll_kmn),
         .numer({iq_diff_post_trunc,{`DLL_SHIFT{1'b0}}}),
         .denom(iq_sum_post_trunc),
         .quotient(quo),
         .remain(rem));

   //Pipe input values after division along with
   //pipelined divider for two divide cycles.
   reg [`CHANNEL_ID_RANGE] tag_post_div_0;
   reg                     sign_post_div_0;
   reg                     start_post_div_0;
   
   reg [`CHANNEL_ID_RANGE] tag_post_div_1;
   reg                     sign_post_div_1;
   reg                     start_post_div_1;
   always @(posedge clk) begin
      if(div_edge_setup) begin
         tag_post_div_0 <= tag_post_setup;
         sign_post_div_0 <= sign_post_setup;
         start_post_div_0 <= start_post_setup;
         
         tag_post_div_1 <= tag_post_div_0;
         sign_post_div_1 <= sign_post_div_0;
         start_post_div_1 <= start_post_div_0;
      end
   end // always @ (posedge clk)

   //Delay post-setup division edge to allow
   //division results to stabilize.
   `KEEP wire div_results_ready;
   delay #(.DELAY(`DLL_DIV_HOLD))
     result_ready_delay(.clk(clk),
                        .reset(reset),
                        .in(div_edge_setup),
                        .out(div_results_ready));

   //Pipe input values after division for hold time.
   `KEEP reg [`DLL_DIV_NUM_RANGE] quo_post_hold;
   reg [`CHANNEL_ID_RANGE] tag_post_hold;
   reg                     sign_post_hold;
   always @(posedge clk) begin
      if(div_results_ready) begin
         quo_post_hold <= quo;
         
         tag_post_hold <= tag_post_div_1;
         sign_post_hold <= sign_post_div_1;
      end
   end // always @ (posedge clk)

   /////////////////////////
   // Result Multiplication
   /////////////////////////

   wire [`DLL_MULT_INPUT_RANGE] mult_input;
   assign mult_input = res_state==`DLL_RES_STATE_AID_1 ?
                       (w_df_kp1[`W_DF_WIDTH-1] ?
                        {{`DLL_MULT_PAD_DOPP{1'b0}},-w_df_kp1} :
                        {{`DLL_MULT_PAD_DOPP{1'b0}},w_df_kp1}) :
                       {{`DLL_MULT_PAD_QUO{1'b0}},quo_post_hold};

   //Shared multiplier for result computation.
   `PRESERVE reg [`DLL_MULT_CONST_RANGE] mult_const;
   `KEEP wire [`DLL_MULT_RES_RANGE] mult_output;
   dll_multiplier #(.INPUT_A_WIDTH(`DLL_MULT_INPUT_WIDTH),
                    .INPUT_B_WIDTH(`DLL_MULT_CONST_WIDTH))
     mult(.clock(clk),
          .dataa(mult_input),
          .datab(mult_const),
          .result(mult_output));

   //Add 0.5 to the result before truncation to round value.
   wire [`DLL_MULT_RES_RANGE] mult_output_round;
   assign mult_output_round = mult_output+
                              (res_state==`DLL_RES_STATE_TAU_1 ? `DLL_A_HALF :
                               res_state==`DLL_RES_STATE_AID_2 ? `DOPP_AID_HALF :
                               `DLL_B_HALF);
   
   `PRESERVE reg [`DLL_RES_STATE_RANGE] res_state;
   always @(posedge clk) begin
      if(reset) begin
         res_state <= `DLL_RES_STATE_IDLE;
         result_ready <= 1'b0;
      end
      else begin
         case(res_state)
           //Calculate tau_prime.
           //tau_prime=(quo*DLL_A_FIX+DLL_A_HALF)>>(DLL_SHIFT+DLL_A_SHIFT)
           `DLL_RES_STATE_TAU_0: begin
              res_state <= `DLL_RES_STATE_DPHI_0;
              mult_const <= `DLL_A_FIX;
           end
           //Calculate phase increment.
           //ca_dphi=(quo*DLL_B_FIX+DLL_B_HALF)>>(DLL_SHIFT+DLL_B_SHIFT)
           `DLL_RES_STATE_DPHI_0: begin
              res_state <= `DLL_RES_STATE_TAU_1;
              mult_const <= `DLL_B_FIX;
           end
           //Retrieve tau_prime.
           `DLL_RES_STATE_TAU_1: begin
              res_state <= `DLL_RES_STATE_DPHI_1;

              if(sign_post_hold)
                tau_prime <= -{1'b0,mult_output_round[`DLL_RES_TAU_RANGE]};
              else
                tau_prime <= {1'b0,mult_output_round[`DLL_RES_TAU_RANGE]};
           end
           //Retrieve ca_dphi.
           `DLL_RES_STATE_DPHI_1: begin
              res_state <= `DLL_RES_STATE_AID_0;

              if(sign_post_hold)
                ca_dphi <= -{1'b0,mult_output_round[`DLL_RES_DPHI_RANGE]};
              else
                ca_dphi <= {1'b0,mult_output_round[`DLL_RES_DPHI_RANGE]};
           end
           //FIXME Waiting here could be a MAJOR problem if
           //FIXME the state machine doesn't go idle before
           //FIXME the next pipelined calculation needs it.
           //Wait for Doppler results and add
           //carrier aiding to ca_dphi.
           `DLL_RES_STATE_AID_0: begin
              res_state <= w_df_ready ?
                           `DLL_RES_STATE_AID_1 :
                           `DLL_RES_STATE_AID_0;
              mult_const <= `DOPP_AID_COEFF;
           end
           //Wait for multiplication to finish.
           `DLL_RES_STATE_AID_1: begin
              res_state <= `DLL_RES_STATE_AID_2;
           end
           //Retrieve ca_dphi.
           `DLL_RES_STATE_AID_2: begin
              res_state <= `DLL_RES_STATE_IDLE;

              result_ready <= 1'b1;

              if(w_df_kp1[`W_DF_WIDTH-1])
                ca_dphi <= ca_dphi-{{`DLL_RES_AID_PAD{1'b0}},mult_output_round[`DLL_RES_AID_RANGE]};
              else
                ca_dphi <= ca_dphi+{{`DLL_RES_AID_PAD{1'b0}},mult_output_round[`DLL_RES_AID_RANGE]};
           end
           default: begin
              res_state <= div_results_ready && start_post_div_1 ?
                           `DLL_RES_STATE_TAU_0 :
                           `DLL_RES_STATE_IDLE;
              result_ready <= 1'b0;
           end
         endcase
      end
   end // always @ (posedge clk)

   assign result_tag = tag_post_hold;
   
endmodule