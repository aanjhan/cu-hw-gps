`include "global.vh"
`include "tracking_loops.vh"
`include "fll.vh"

`define DEBUG
`include "debug.vh"

module fll(
    input                                  clk,
    input                                  reset,
    //Control interface.
    input                                  start,
    input [`CHANNEL_ID_RANGE]              tag,
    output wire                            starting,
    //Channel tracking history.
    input [`IQ_RANGE]                      iq_prompt_k,
    input [`IQ_RANGE]                      iq_prompt_km1,
    input [`ACC_RANGE_TRACK]               i_prompt_k,
    input [`ACC_RANGE_TRACK]               q_prompt_k,
    input [`ACC_RANGE_TRACK]               i_prompt_km1,
    input [`ACC_RANGE_TRACK]               q_prompt_km1,
    input [`W_DF_RANGE]                    w_df_k,
    input [`W_DF_DOT_RANGE]                w_df_dot_k,
    //Results interface.
    output reg                             result_ready,
    output wire [`CHANNEL_ID_RANGE]        result_tag,
    output reg [`DOPPLER_INC_RANGE]        doppler_inc_kp1,
    output reg [`W_DF_RANGE]               w_df_kp1,
    output reg [`W_DF_DOT_RANGE]           w_df_dot_kp1);
   
   //Generate FLL clock at speed required for division.
   //Note: clk_fll is forced to keep for timing constraints.
   `PRESERVE reg [`FLL_CLK_RANGE] fll_clk_count;
   (* preserve*) reg              clk_fll;
   always @(posedge clk) begin
      fll_clk_count <= reset ? `FLL_CLK_WIDTH'd`FLL_CLK_MAX :
                       fll_clk_count==`FLL_CLK_WIDTH'd`FLL_CLK_MAX ? `FLL_CLK_WIDTH'h0 :
                       fll_clk_count+`FLL_CLK_WIDTH'h1;

      clk_fll <= reset ? 1'b0 :
                 fll_clk_count==`FLL_CLK_WIDTH'd`FLL_CLK_MAX ? ~clk_fll :
                 clk_fll;
   end

   //Start a new operation on the edge of the FLL clock
   //when start is asserted from the top level.
   `KEEP wire starting_trunc;
   assign starting_trunc = start &&
                           ~clk_fll &&
                           fll_clk_count==`FLL_CLK_WIDTH'd`FLL_CLK_MAX;

   //Doppler phase increment calculation:
   //  dtheta=((Q_k*I_km1-I_k*Q_km1)<<ANGLE_SHIFT)/(IQ_k*IQ_km1)
   //  wdfdot_kp1=wdfdot_k+(A_FLL*dtheta)>>FLL_CONST_SHIFT
   //  wdf_kp1=wdf_k+wdfdot_k*T+(B_FLL*dtheta)>>FLL_CONST_SHIFT
   //
   //Required FLL parameters.
   //  --numerator=(Q_k*I_km1-I_k*Q_km1)
   //  --denominator=IQ_k*IQ_km1

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

   `KEEP wire continue_trunc;
   delay #(.DELAY(2))
     div_edge_delay_1(.clk(clk),
                      .reset(reset),
                      .in(starting_trunc),
                      .out(continue_trunc));

   `PRESERVE reg [`FLL_INDEX_RANGE] trunc_index;
   always @(posedge clk) begin
      trunc_index <= continue_trunc ? trunc_index_value : trunc_index;
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
              st_state <= continue_trunc ?
                          `FLL_ST_STATE_IQ :
                          `FLL_ST_STATE_IDLE;

              start_op_setup <= 1'b0;
           end
         endcase
      end
   end // always @ (posedge clk)

   //Assert starting back to the top level after
   //truncation has finished and input values are
   //no longer needed.
   delay #(.DELAY(4))
     starting_delay(.clk(clk),
                    .reset(reset),
                    .in(continue_trunc),
                    .out(starting));

   //Pipe values necessary for calculation.
   reg [`W_DF_RANGE]     w_df_k_post_trunc;
   reg [`W_DF_DOT_RANGE] w_df_dot_k_post_trunc;
   always @(posedge clk) begin
      w_df_k_post_trunc <= starting ? w_df_k : w_df_k_post_trunc;
      w_df_dot_k_post_trunc <= starting ? w_df_dot_k : w_df_dot_k_post_trunc;
   end

   ////////////////////////////////////////
   // Numerator/Denominator Computation
   ////////////////////////////////////////

   //Shared multiplier for value calculation.
   reg [`FLL_OP_RANGE]        mult_a;
   reg [`FLL_OP_RANGE]        mult_b;
   wire [2*`FLL_OP_WIDTH-1:0] mult_output;
   fll_multiplier #(.INPUT_A_WIDTH(`FLL_OP_WIDTH),
                    .INPUT_B_WIDTH(`FLL_OP_WIDTH))
     mult(.clock(clk),
          .dataa(mult_a),
          .datab(mult_b),
          .result(mult_output));
   
   `KEEP wire [`FLL_DEN_RANGE] mult_result;
   assign mult_result = mult_output[`FLL_DEN_RANGE];

   //Division parameters.
   reg [`FLL_NUM_RANGE] numerator;
   reg [`FLL_DEN_RANGE] denominator;
   reg                  start_div;

   //Operand setup state machine.
   `PRESERVE reg [`FLL_OP_STATE_RANGE] op_setup_state;
   `KEEP wire div_clk_edge_pending;
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

              //Numerator is in *:`ANGLE_SHIFT fixed-point.
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

              //Numerator is in *:`ANGLE_SHIFT fixed-point.
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
           end
           default: begin
             op_setup_state <= start_op_setup ?
                               `FLL_OP_STATE_MULT_0 :
                               `FLL_OP_STATE_IDLE;
           end
         endcase // case (op_setup_state)
         
         //Don't deassert division start signal
         //until after division clock posedge.
         start_div <= op_setup_state==`FLL_OP_STATE_FINISH ? 1'b1 :
                      div_clk_edge_pending ? 1'b0 :
                      start_div;
      end
   end // always @ (clk)

   //Pipe values necessary for calculation.
   //Note: This requires that the above computation
   //      complete before the next truncation completes.
   reg [`W_DF_RANGE]     w_df_k_post_comp;
   reg [`W_DF_DOT_RANGE] w_df_dot_k_post_comp;
   always @(posedge clk) begin
      w_df_k_post_comp <= start_div ? w_df_k_post_trunc : w_df_k_post_comp;
      w_df_dot_k_post_comp <= start_div ? w_df_dot_k_post_trunc : w_df_dot_k_post_comp;
   end

   ////////////////////
   // Division
   ////////////////////

   //Generate FLL division clock from system clock.
   `PRESERVE reg [`FLL_CLK_RANGE] div_clk_count;
   wire                 div_clk_max_count;
   assign div_clk_max_count = div_clk_count==`FLL_CLK_WIDTH'd`FLL_CLK_MAX;

   //Disable the division clock if a new division
   //is not to set to start.
   wire div_clk_disable;
   assign div_clk_disable = div_clk_edge_pending && !start_div;
   
   //Note: clk_div is forced to keep for timing constraints.
   `PRESERVE reg [1:0]            div_clk_state;
   (* keep *) reg                  clk_div;
   always @(posedge clk) begin
      if(reset) begin
            div_clk_state <= 2'd3;
            div_clk_count <= `FLL_CLK_WIDTH'd`FLL_CLK_MAX;
            clk_div <= 1'b0;
      end
      else begin
         case(div_clk_state)
           2'd0: begin
              div_clk_state <= div_clk_edge_pending ?
                               (start_div ? 2'd0 : 2'd1) :
                               2'd0;
              div_clk_count <= div_clk_max_count ?
                               `FLL_CLK_WIDTH'd0 :
                               div_clk_count+`FLL_CLK_WIDTH'd1;
              clk_div <= div_clk_max_count ? ~clk_div : clk_div;
           end
           2'd1: begin
              div_clk_state <= div_clk_disable ? 2'd3 :
                               div_clk_edge_pending ? 2'd0 :
                               2'd1;
              div_clk_count <= div_clk_disable ? div_clk_count :
                               div_clk_max_count ? `FLL_CLK_WIDTH'd0 :
                               div_clk_count+`FLL_CLK_WIDTH'd1;
              clk_div <= div_clk_max_count && !div_clk_disable ? ~clk_div : clk_div;
           end
           default: begin
              div_clk_state <= start_div ? 2'd0 : 2'd3;
              div_clk_count <= start_div ? `FLL_CLK_WIDTH'd0 :`FLL_CLK_WIDTH'd`FLL_CLK_MAX;
              clk_div <= start_div;
           end
      endcase // case (div_clk_state)
      end
   end // always @ (posedge clk)

   //Flag the cycle before the posedge of the
   //division clock to latch operands and clear
   //start_div flag.
   assign div_clk_edge_pending = (div_clk_state!=2'd3 || start_div) &&
                                 div_clk_max_count &&
                                 ~clk_div;

   //Take the absolute value of the numerator
   //to reduce multiply/divide complexity.
   wire [`FLL_QUO_RANGE] numerator_abs;
   abs #(.WIDTH(`FLL_NUM_WIDTH))
     num_abs(.in(numerator),
             .out(numerator_abs));

   //Latch division operands for specified setup time.
   reg [`FLL_QUO_RANGE] numerator_in;
   reg [`FLL_DEN_RANGE] denominator_in;
   reg                  div_sign;
   always @(posedge clk) begin
      numerator_in <= div_clk_edge_pending ? numerator_abs : numerator_in;
      denominator_in <= div_clk_edge_pending ? denominator : denominator_in;
      div_sign <= div_clk_edge_pending ? `MIXING_SIGN^numerator[`FLL_NUM_WIDTH-1] : div_sign;
   end

   //Note: clk_div_kmn is forced to keep for timing constraints.
   (* keep *) wire clk_div_kmn;
   delay #(.DELAY(`FLL_DIV_SETUP))
     div_clk_delay(.clk(clk),
                   .reset(reset),
                   .in(clk_div),
                   .out(clk_div_kmn));

   `KEEP wire div_setup_complete;
   delay #(.DELAY(`FLL_DIV_SETUP))
     div_start_delay(.clk(clk),
                     .reset(reset),
                     .in(div_clk_edge_pending && !div_clk_disable),
                     .out(div_setup_complete));

   //Pipe division result sign along
   //with 2-stage division.
   reg div_sign_km1;
   reg div_sign_km2;
   always @(posedge clk_div_kmn) begin
      div_sign_km1 <= div_sign;
      div_sign_km2 <= div_sign_km1;
   end

   //Divider.
   `KEEP wire [`FLL_QUO_RANGE] quo;
   wire [`FLL_DEN_RANGE] rem;
   fll_divider #(.NUM_WIDTH(`FLL_QUO_WIDTH),
                 .DEN_WIDTH(`FLL_DEN_WIDTH))
     div(.clock(clk_div_kmn),
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

   //Store the result (i.e. the angle between the
   //vectors). This angle is always positive.
   reg                            dtheta_sign;
   `PRESERVE reg [`FLL_QUO_RANGE] dtheta;
   always @(posedge clk) begin
      dtheta <= div_results_ready ? quo : dtheta;
      dtheta_sign <= div_results_ready ? div_sign_km2 : dtheta_sign;
   end

   wire div_clk_negedge;
   strobe div_clk_strobe(.clk(clk),
                         .reset(reset),
                         .in(~clk_div),
                         .out(div_clk_negedge));
   
   //Pipe values necessary for calculation.
   `PRESERVE reg [`W_DF_RANGE]     w_df_k_post_div_0;
   `PRESERVE reg [`W_DF_DOT_RANGE] w_df_dot_k_post_div_0;
   `PRESERVE reg [`W_DF_RANGE]     w_df_k_post_div_1;
   `PRESERVE reg [`W_DF_DOT_RANGE] w_df_dot_k_post_div_1;
   `PRESERVE reg [`W_DF_RANGE]     w_df_k_post_div_2;
   `PRESERVE reg [`W_DF_DOT_RANGE] w_df_dot_k_post_div_2;
   always @(posedge clk) begin
      if(div_clk_negedge) begin
         w_df_k_post_div_0 <= w_df_k_post_comp;
         w_df_dot_k_post_div_0 <= w_df_dot_k_post_comp;
         w_df_k_post_div_1 <= w_df_k_post_div_0;
         w_df_dot_k_post_div_1 <= w_df_dot_k_post_div_0;
         w_df_k_post_div_2 <= w_df_k_post_div_1;
         w_df_dot_k_post_div_2 <= w_df_dot_k_post_div_1;
      end
   end

   /////////////////////////
   // Result Computation
   /////////////////////////

   //Shared multiplier.
   reg [`FLL_CONST_RANGE]                            res_mult_a;
   reg [`FLL_RES_MULT_B_RANGE]                       res_mult_b;
   wire [`FLL_CONST_WIDTH+`FLL_RES_MULT_B_WIDTH-1:0] res_mult_output;
   fll_multiplier #(.INPUT_A_WIDTH(`FLL_CONST_WIDTH),
                    .INPUT_B_WIDTH(`FLL_RES_MULT_B_WIDTH),
                    .SIGN("UNSIGNED"))
     res_mult(.clock(clk),
              .dataa(res_mult_a),
              .datab(res_mult_b),
              .result(res_mult_output));

   `KEEP wire [`FLL_CONST_RES_RANGE] res_mult_result;
   assign res_mult_result = res_mult_output[`FLL_CONST_RES_RANGE];

   `PRESERVE reg [`FLL_RES_STATE_RANGE] res_state;
   always @(posedge clk) begin
      if(reset) begin
         res_state <= `FLL_RES_STATE_IDLE;
         result_ready <= 1'b0;
      end
      else begin
         case(res_state)
           //Calculate w_df_kp1.
           //w_df_kp1=w_df_k+
           //         (w_df_dot_k*FLL_T)>>FLL_PER_SHIFT+
           //         (FLL_B*dtheta)>>FLL_CONST_SHIFT
           `FLL_RES_STATE_W_DF_0: begin
              res_state <= `FLL_RES_STATE_W_DF_1;
              res_mult_a <= `FLL_T;
              //FIXME THE POST_DIV_* SIGNALS ARE A VERY DANGEROUS HACK.
              //FIXME Find a better way to delay the post_div values than this.
              res_mult_b <= w_df_dot_k_post_div_1[`W_DF_DOT_WIDTH-1] ?
                            {{`FLL_RES_W_DF_DOT_PAD{1'b0}},-w_df_dot_k_post_div_1} :
                            {{`FLL_RES_W_DF_DOT_PAD{1'b0}},w_df_dot_k_post_div_1};
           end
           `FLL_RES_STATE_W_DF_1: begin
              res_state <= `FLL_RES_STATE_W_DF_2;
              res_mult_a <= `FLL_B;
              res_mult_b <= {{`FLL_RES_DT_PAD{1'b0}},dtheta};
           end
           `FLL_RES_STATE_W_DF_2: begin
              res_state <= `FLL_RES_STATE_W_DF_DOT_0;

              if(w_df_dot_k_post_div_1[`W_DF_DOT_WIDTH-1])
                w_df_kp1 <= w_df_k_post_div_1-res_mult_result[`FLL_RES_T_RANGE];
              else
                w_df_kp1 <= w_df_k_post_div_1+res_mult_result[`FLL_RES_T_RANGE];
           end
           //Calculate w_df_dot_kp1.
           //w_df_dot_kp1=w_df_dot_k+(FLL_A*dtheta)>>FLL_CONST_SHIFT
           `FLL_RES_STATE_W_DF_DOT_0: begin
              res_state <= `FLL_RES_STATE_W_DF_DOT_1;
              res_mult_a <= `FLL_A;
              res_mult_b <= {{`FLL_RES_DT_PAD{1'b0}},dtheta};

              if(dtheta_sign)
                w_df_kp1 <= w_df_kp1-res_mult_result[`FLL_RES_B_RANGE];
              else
                w_df_kp1 <= w_df_kp1+res_mult_result[`FLL_RES_B_RANGE];
           end
           `FLL_RES_STATE_W_DF_DOT_1: begin
              res_state <= `FLL_RES_STATE_INC_0;
           end
           //Calculate Doppler phase increment.
           //dopp_inc_kp1=w_df_kp1*(2^(CARRIER_ACC_WIDTH-ANGLE_SHIFT)/(2*PI)/F_S)
           `FLL_RES_STATE_INC_0: begin
              res_state <= `FLL_RES_STATE_INC_1;
              res_mult_a <= `W_DF_TO_INC;
              res_mult_b <= w_df_kp1[`W_DF_WIDTH-1] ?
                            {{`FLL_RES_W_DF_PAD{1'b0}},-w_df_kp1} :
                            {{`FLL_RES_W_DF_PAD{1'b0}},w_df_kp1};

              if(dtheta_sign)
                w_df_dot_kp1 <= w_df_dot_k_post_div_2-res_mult_result[`FLL_RES_A_RANGE];
              else
                w_df_dot_kp1 <= w_df_dot_k_post_div_2+res_mult_result[`FLL_RES_A_RANGE];
           end
           `FLL_RES_STATE_INC_1: begin
              res_state <= `FLL_RES_STATE_FINISH;
           end
           `FLL_RES_STATE_FINISH: begin
              res_state <= `FLL_RES_STATE_IDLE;
              
              result_ready <= 1'b1;
              if(w_df_kp1[`W_DF_WIDTH-1])
                doppler_inc_kp1 <= -res_mult_result[`FLL_RES_INC_RANGE];
              else
                doppler_inc_kp1 <= res_mult_result[`FLL_RES_INC_RANGE];
           end
           default: begin
              res_state <= div_results_ready ?
                           `FLL_RES_STATE_W_DF_0 :
                           `FLL_RES_STATE_IDLE;
              result_ready <= 1'b0;
           end
         endcase
      end
   end // always @ (posedge clk)

   //Delay incoming tag on the FLL clock.
   delay #(.DELAY(`FLL_TAG_DELAY),
           .WIDTH(`CHANNEL_ID_WIDTH))
     tag_delay(.clk(clk_fll),
               .reset(reset),
               .in(tag),
               .out(result_tag));
   
endmodule