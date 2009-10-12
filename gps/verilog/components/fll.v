`include "global.vh"
`include "fll.vh"

`define DEBUG
`include "debug.vh"

module fll(
    input                                  clk,
    input                                  reset,
    //Control interface.
    input                                  start,
    input [`CHANNEL_ID_RANGE]              tag,
    //Channel tracking history.
    input [`IQ_RANGE]                      iq_prompt_k,
    input [`IQ_RANGE]                      iq_prompt_km1,
    input [`ACC_RANGE_TRACK]               i_prompt_k,
    input [`ACC_RANGE_TRACK]               q_prompt_k,
    input [`ACC_RANGE_TRACK]               i_prompt_km1,
    input [`ACC_RANGE_TRACK]               q_prompt_km1,
    input [`DOPPLER_SHIFT_RANGE]           w_df_k,
    input [`DOPPLER_SHIFT_DOT_RANGE]       w_df_dot_k,
    //Results interface.
    output reg                             result_ready,
    output reg [`CHANNEL_ID_RANGE]         result_tag,
    output reg [`DOPPLER_INC_RANGE]        doppler_inc,
    output reg [`DOPPLER_SHIFT_RANGE]      w_df_kp1,
    output reg [`DOPPLER_SHIFT_DOT_RANGE]  w_df_dot_kp1);

   //Doppler phase increment calculation:
   //  dtheta=((Q_k*I_km1-I_k*Q_km1)<<ANGLE_SHIFT)/(IQ_k*IQ_km1)
   //  wdfdot_kp1=wdfdot_k+(A_FLL*dtheta)>>FLL_CONST_SHIFT
   //  wdf_kp1=wdf_k+wdfdot_k*T+(B_FLL*dtheta)>>FLL_CONST_SHIFT
   //
   //Required FLL parameters.
   //  --numerator=(Q_k*I_km1-I_k*Q_km1)
   //  --denominator=IQ_k*IQ_km1

   //Generate FLL clock from system clock.
   reg [`FLL_CLK_RANGE] fll_clk_count;
   reg clk_fll;
   reg div_edge;
   always @(posedge clk) begin
      fll_clk_count <= reset ? `FLL_CLK_WIDTH'd`FLL_CLK_MAX :
                       fll_clk_count==`FLL_CLK_MAX ? `FLL_CLK_WIDTH'h0 :
                       fll_clk_count+`FLL_CLK_WIDTH'h1;

      clk_fll <= reset ? 1'b0 :
                 fll_clk_count==`FLL_CLK_WIDTH'd`FLL_CLK_MAX ? ~clk_fll :
                 clk_fll;

      div_edge <= (!reset &&
                   fll_clk_count==`FLL_CLK_WIDTH'd`FLL_CLK_MAX &&
                   !clk_fll) ?
                  start :
                  1'b0;
   end // always @ (posedge clk)

   //////////////////////////////
   // Operand Smart-Truncation
   //////////////////////////////

   //Truncate operands to specified width, starting
   //at the most significant bit in the larger of
   //the two operand values.
   //Note: the priority encoders take 2 cycles to complete.
   //Note: the IQ values are always at least as wide as the
   //      I/Q values (vector magnitude).
   `KEEP wire [`FLL_INDEX_RANGE] iq_k_index;
   fll_priority_enc iq_k_priority(.clk(clk),
                                 .in(iq_prompt_k),
                                 .out(iq_k_index));
   
   `KEEP wire [`FLL_INDEX_RANGE] iq_km1_index;
   fll_priority_enc iq_km1_priority(.clk(clk),
                                    .in(iq_prompt_km1),
                                    .out(iq_km1_index));
   
   wire [`FLL_INDEX_RANGE] trunc_index_value;
   assign trunc_index_value = iq_k_index>iq_km1_index ?
                              iq_k_index :
                              iq_km1_index;

   wire div_edge_km2;
   delay #(.DELAY(2))
     div_edge_delay_1(.clk(clk),
                      .reset(reset),
                      .in(div_edge),
                      .out(div_edge_km2));

   `PRESERVE reg [`FLL_INDEX_RANGE] trunc_index;
   always @(posedge clk) begin
      trunc_index <= div_edge_km2 ? trunc_index_value : trunc_index;
   end

   reg [`ACC_RANGE_TRACK] trunc0_in;
   wire [`FLL_OP_RANGE] trunc0_out;
   fll_truncate trunc0(.index(trunc_index),
                       .in(trunc0_in),
                       .out(trunc0_out));

   reg [`ACC_RANGE_TRACK] trunc1_in;
   wire [`FLL_OP_RANGE] trunc1_out;
   fll_truncate trunc1(.index(trunc_index),
                       .in(trunc1_in),
                       .out(trunc1_out));

   //Smart-truncated operating parameters.
   reg [`FLL_OP_RANGE] iq_k_trunc;
   reg [`FLL_OP_RANGE] iq_km1_trunc;
   reg [`FLL_OP_RANGE] i_k_trunc;
   reg [`FLL_OP_RANGE] q_k_trunc;
   reg [`FLL_OP_RANGE] i_km1_trunc;
   reg [`FLL_OP_RANGE] q_km1_trunc;
   reg                 start_op_setup;

   //Smart-truncation state machine.
   `PRESERVE reg [`FLL_ST_STATE_RANGE] st_state;
   always @(posedge clk) begin
      if(reset) begin
         st_state <= `FLL_ST_STATE_IDLE;
         start_op_setup <= 1'b0;
      end
      else begin
         case(st_state)
           //Setup IQ_* truncation.
           `FLL_ST_STATE_IQ: begin
              st_state <= `FLL_ST_STATE_K;
              //Note: accumulator values are two's complement,
              //      while IQ values are unsigned.
              trunc0_in <= {1'b0,iq_prompt_k};
              trunc1_in <= {1'b0,iq_prompt_km1};
           end
           //Setup I_k/Q_k truncation.
           `FLL_ST_STATE_K: begin
              st_state <= `FLL_ST_STATE_KM1;
              trunc0_in <= i_prompt_k;
              trunc1_in <= q_prompt_k;

              iq_k_trunc <= trunc0_out;
              iq_km1_trunc <= trunc1_out;
           end
           //Setup I_km1/Q_km1 truncation.
           `FLL_ST_STATE_KM1: begin
              st_state <= `FLL_ST_STATE_FINISH;
              trunc0_in <= i_prompt_km1;
              trunc1_in <= q_prompt_km1;

              i_k_trunc <= trunc0_out;
              q_k_trunc <= trunc1_out;
           end
           //Retrieve values and start FLL computation.
           `FLL_ST_STATE_FINISH: begin
              st_state <= `FLL_ST_STATE_IDLE;

              i_km1_trunc <= trunc0_out;
              q_km1_trunc <= trunc1_out;
              start_op_setup <= 1'b1;
           end
           default: begin
              st_state <= div_edge_km2 ?
                          `FLL_ST_STATE_IQ :
                          `FLL_ST_STATE_IDLE;

              start_op_setup <= 1'b0;
           end
         endcase
      end
   end

   ////////////////////////////////////////
   // Numerator/Denominator Computation
   ////////////////////////////////////////

   //Shared multiplier for value calculation.
   reg [`FLL_OP_RANGE]   mult_a;
   reg [`FLL_OP_RANGE]   mult_b;
   `KEEP wire [`FLL_DEN_RANGE] mult_result;
   fll_multiplier #(.INPUT_A_WIDTH(`FLL_OP_WIDTH),
                    .INPUT_B_WIDTH(`FLL_OP_WIDTH),
                    .OUTPUT_WIDTH(`FLL_DEN_WIDTH))
     mult(.clock(clk),
          .dataa(mult_a),
          .datab(mult_b),
          .result(mult_result));

   //Division parameters.
   reg [`FLL_NUM_RANGE] numerator;
   reg [`FLL_DEN_RANGE] denominator;
   reg                  start_div;

   //Operand setup state machine.
   `PRESERVE reg [`FLL_OP_STATE_RANGE] op_setup_state;
   always @(posedge clk) begin
      if(reset) begin
         op_setup_state <= `FLL_OP_STATE_IDLE;
         start_div <= 1'b0;
      end
      else begin
         case(op_setup_state)
           //Compute Q_k*I_km1.
           `FLL_OP_STATE_MULT_0: begin
              op_setup_state <= `FLL_OP_STATE_MULT_1;
              mult_a <= q_k_trunc;
              mult_b <= i_km1_trunc;
           end
           `FLL_OP_STATE_MULT_1: begin
              op_setup_state <= `FLL_OP_STATE_MULT_2;
              mult_a <= q_k_trunc;
              mult_b <= i_km1_trunc;
           end
           //Store Q_k*I_km1 and compute I_k*Q_km1.
           `FLL_OP_STATE_MULT_2: begin
              op_setup_state <= `FLL_OP_STATE_MULT_3;
              mult_a <= i_k_trunc;
              mult_b <= q_km1_trunc;

              //Numerator is in *:`FLL_OP_SHIFT fixed-point.
              numerator <= {mult_result,{`ANGLE_SHIFT{1'b0}}};
           end
           `FLL_OP_STATE_MULT_3: begin
              op_setup_state <= `FLL_OP_STATE_MULT_4;
              mult_a <= i_k_trunc;
              mult_b <= q_km1_trunc;
           end
           //Store numerator and compute IQ_k*IQ_km1.
           `FLL_OP_STATE_MULT_4: begin
              op_setup_state <= `FLL_OP_STATE_MULT_5;
              mult_a <= iq_k_trunc;
              mult_b <= iq_km1_trunc;

              //Numerator is in *:`FLL_OP_SHIFT fixed-point.
              numerator <= numerator-{mult_result,{`ANGLE_SHIFT{1'b0}}};
           end
           `FLL_OP_STATE_MULT_5: begin
              op_setup_state <= `FLL_OP_STATE_FINISH;
              mult_a <= iq_k_trunc;
              mult_b <= iq_km1_trunc;
           end
           //Store denominator and start division.
           `FLL_OP_STATE_FINISH: begin
              op_setup_state <= `FLL_OP_STATE_IDLE;
              denominator <= mult_result;
              start_div <= 1'b1;
           end
           default: begin
             op_setup_state <= start_op_setup ?
                               `FLL_OP_STATE_MULT_0 :
                               `FLL_OP_STATE_IDLE;

              //Don't deassert division start signal
              //until after division clock posedge.
              start_div <= clk_fll ? 1'b0 : start_div;
           end
         endcase
      end
   end // always @ (clk)

   ////////////////////
   // Division
   ////////////////////

   //Latch division operands for specified setup time.
   reg [`FLL_NUM_RANGE]       numerator_in;
   reg [`FLL_DEN_RANGE]       denominator_in;
   always @(posedge clk_fll) begin
      numerator_in <= start_div ? numerator : numerator_in;
      denominator_in <= start_div ? denominator : denominator_in;
   end

   `KEEP wire clk_fll_kmn;
   delay #(.DELAY(`FLL_DIV_SETUP))
     div_clk_delay(.clk(clk),
                   .reset(reset),
                   .in(clk_fll),
                   .out(clk_fll_kmn));

   `KEEP wire div_setup_complete;
   delay #(.DELAY(`FLL_DIV_SETUP))
     div_start_delay(.clk(clk),
                     .reset(reset),
                     .in(start_div && clk_fll),
                     .out(div_setup_complete));

   //Divider.
   `KEEP wire [`FLL_NUM_RANGE] quo;
   wire [`FLL_DEN_RANGE] rem;
   fll_divider #(.NUM_WIDTH(`FLL_NUM_WIDTH),
                 .DEN_WIDTH(`FLL_DEN_WIDTH))
     div(.clock(clk_fll_kmn),
         .numer(numerator_in),
         .denom(denominator_in),
         .quotient(quo),
         .remain(rem));

   `KEEP wire div_results_ready;
   delay #(.DELAY(`FLL_CLK_COUNT+`FLL_DIV_HOLD))
     div_hold_delay(.clk(clk),
                    .reset(reset),
                    .in(div_setup_complete),
                    .out(div_results_ready));
   
   `PRESERVE reg [`FLL_NUM_RANGE] dtheta;
   always @(posedge clk) begin
      dtheta <= div_results_ready ? quo : dtheta;
   end

   /////////////////////////
   // Result Computation
   /////////////////////////

   //Shared signed multiplier.
   //Note: constants are forced positive.
   reg [`FLL_CONST_RANGE]            res_mult_a;
   reg [`FLL_NUM_RANGE]              res_mult_b;
   `KEEP wire [`FLL_CONST_RES_RANGE] res_mult_result;
   fll_multiplier #(.INPUT_A_WIDTH(`FLL_CONST_WIDTH+1),
                    .INPUT_B_WIDTH(`FLL_NUM_WIDTH),
                    .OUTPUT_WIDTH(`FLL_CONST_RES_WIDTH))
     res_mult(.clock(clk),
              .dataa({1'b0,res_mult_a}),
              .datab(res_mult_b),
              .result(res_mult_result));

   `PRESERVE reg [`FLL_RES_STATE_RANGE] res_state;
   always @(posedge clk) begin
      if(reset) begin
         res_state <= `FLL_RES_STATE_IDLE;
         result_ready <= 1'b0;
      end
      else begin
         case(res_state)
           //Calculate w_df_dot_kp1.
           //w_df_dot_kp1=w_df_dot_k+(FLL_A*dtheta)>>FLL_CONST_SHIFT
           `FLL_RES_STATE_W_DF_DOT: begin
              res_state <= `FLL_RES_STATE_W_DF_0;
              res_mult_a <= `FLL_A;
              res_mult_b <= dtheta;
           end
           //Calculate w_df_kp1.
           //w_df_kp1=w_df_k+
           //         (w_df_dot_k*FLL_T)>>FLL_PER_SHIFT+
           //         (FLL_A*dtheta)>>FLL_CONST_SHIFT
           `FLL_RES_STATE_W_DF_0: begin
              res_state <= `FLL_RES_STATE_W_DF_1;
              res_mult_a <= `FLL_T;
              res_mult_b <= w_df_dot_k;

              w_df_dot_kp1 <= w_df_dot_k+(res_mult_result>>`FLL_CONST_SHIFT);
           end
           `FLL_RES_STATE_W_DF_1: begin
              res_state <= `FLL_RES_STATE_FINISH;
              res_mult_a <= `FLL_B;
              res_mult_b <= dtheta;

              w_df_kp1 <= w_df_kp1+(res_mult_result>>`FLL_PER_SHIFT);
           end
           //FIXME Calculate phase increment and get w_df from that?
           //FIXME Or just calculate phase increment separately.
           `FLL_RES_STATE_FINISH: begin
              res_state <= `FLL_RES_STATE_IDLE;
              w_df_kp1 <= w_df_k+(res_mult_result>>`FLL_CONST_SHIFT);
              result_ready <= 1'b1;
           end
           default: begin
              res_state <= div_results_ready ?
                           `FLL_RES_STATE_W_DF_DOT :
                           `FLL_RES_STATE_IDLE;
              result_ready <= 1'b0;
           end
         endcase
      end
   end
   
endmodule