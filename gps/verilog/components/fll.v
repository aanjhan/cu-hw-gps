`include "global.vh"
`include "fll.vh"

`define DEBUG
`include "debug.vh"

module fll(
    input                                  clk,
    input                                  reset,
    //Channel control interface.
    input                                  start,
    input [`CHANNEL_ID_RANGE]              tag,
    //Channel tracking history.
    input [`IQ_WIDTH]                      iq_prompt
    input [`IQ_WIDTH]                      iq_prompt_km1,
    input [`ACC_WIDTH]                     i_prompt_k,
    input [`ACC_WIDTH]                     q_prompt_k,
    input [`ACC_WIDTH]                     i_prompt_km1,
    input [`ACC_WIDTH]                     q_prompt_km1,
    input [`DOPPLER_SHIFT_RANGE]           wdf_k,
    input [`DOPPLER_SHIFT_DOT_RANGE]       wdfdot_k,
    //Doppler results interface.
    output reg [`DOPPLER_INC_RANGE]        doppler_inc,
    output reg [`DOPPLER_SHIFT_RANGE]      wdf_kp1,
    output reg [`DOPPLER_SHIFT_DOT_RANGE]  wdfdot_kp1);

   //Doppler phase increment calculation:
   //  dtheta=((Q_k*I_km1-I_k*Q_km1)<<ANGLE_SHIFT)/(IQ_k*IQ_km1)
   //  wdfdot_kp1=wdfdot_k+(A_FLL*dtheta)>>FLL_CONST_SHIFT
   //  wdf_kp1=wdf_k+wdfdot_k*T+(B_FLL*dtheta)>>FLL_CONST_SHIFT
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

      div_edge <= !reset && fll_clk_count==`FLL_CLK_WIDTH'd`FLL_CLK_MAX && !clk_fll ? 1'b1 : 1'b0;
   end // always @ (posedge clk)

   //Shared multiplier for value calculation.
   reg [`IQ_RANGE] mult_a;
   reg [`IQ_RANGE] mult_b;
   wire [`I2Q2_RANGE_TRACK] mult_result;
   fll_multiplier #(INPUT_A_WIDTH(`IQ_WIDTH),
                    INPUT_B_WIDTH(`IQ_WIDTH),
                    OUTPUT_WIDTH(`I2Q2_WIDTH_TRACK))
     mult(.clock(clk),
          .dataa(mult_a),
          .datab(mult_b),
          .result(mult_result));

   //Divider.
   wire [`FLL_NUM_RANGE] numerator;
   wire [`I2Q2_RANGE_TRACK] denominator;
   wire [`FLL_NUM_RANGE] quo;
   wire [`I2Q2_RANGE_TRACK] rem;
   fll_divider #(NUM_WIDTH(`FLL_NUM_WIDTH),
                 DEN_WIDTH(`I2Q2_WIDTH_TRACK))
     div(.clock(clk_fll),
         .numer(numerator),
         .denom(denominator),
         .quotient(quo),
         .remain(rem));

   reg [`FLL_STATE_RANGE] state;
   reg []                 divide_counter;
   always @(clk) begin
      if(reset) begin
         state <= FLL_STATE_IDLE;
      end
      else begin
         case(state)
           //Compute Q_k*I_km1.
           `FLL_STATE_0: begin
              state <= `FLL_STATE_1;
              mult_a <= q_prompt_k;
              mult_b <= i_prompt_km1;
           end
           `FLL_STATE_1: begin
              state <= `FLL_STATE_2;
              mult_a <= q_prompt_k;
              mult_b <= i_prompt_km1;
           end
           //Store Q_k*I_km1 and compute I_k*Q_km1.
           `FLL_STATE_2: begin
              state <= `FLL_STATE_3;
              mult_a <= i_prompt_k;
              mult_b <= q_prompt_km1;

              numerator <= {{(`FLL_NUM_WIDTH-`I2Q2_WIDTH_TRACK){1'b0}},mult_result};
           `FLL_STATE_3: begin
              state <= `FLL_STATE_4;
              mult_a <= i_prompt_k;
              mult_b <= q_prompt_km1;
           end
           //Store numerator and compute IQ_k*IQ_km1.
           `FLL_STATE_4: begin
              state <= `FLL_STATE_5;
              mult_a <= iq_prompt_k;
              mult_b <= iq_prompt_km1;

              numerator <= numerator-{{(`FLL_NUM_WIDTH-`I2Q2_WIDTH_TRACK){1'b0}},mult_result};
           `FLL_STATE_5: begin
              state <= `FLL_STATE_6;
              mult_a <= iq_prompt_k;
              mult_b <= iq_prompt_km1;
           end
           `FLL_STATE_6: begin
              state <= 1'b0 ? `FLL_STATE_6 : `FLL_STATE_7;//FIXME
              mult_a <= iq_prompt_k;
              mult_b <= iq_prompt_km1;
           end
           default:
             state <= start ? `FLL_STATE_0 : `FLL_STATE_IDLE;
         endcase
      end
   end
   
endmodule