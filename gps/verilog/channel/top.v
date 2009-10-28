`include "../components/global.vh"
`include "top__channel.vh"
`include "../components/channel__tracking_loops.vh"

`define DEBUG
`include "../components/debug.vh"

//`define HIGH_SPEED

`include "../components/subchannel.vh"

module top(
    input                            clk,
    input                            global_reset,
    input [`MODE_RANGE]              mode,
    //Sample data.
    input                            clk_sample,
    input                            sample_valid,
    input                            feed_reset,
    input                            feed_complete,
    input [`INPUT_RANGE]             data,
    //Code control.
    input [4:0]                      prn,
    output wire [`CS_RANGE]          code_shift,
    //Channel history.
    output wire                      i2q2_valid,
    output wire [`I2Q2_RANGE]        i2q2_early,
    output wire [`I2Q2_RANGE]        i2q2_prompt,
    output wire [`I2Q2_RANGE]        i2q2_late,
    output wire                      tracking_ready,
    output wire [`ACC_RANGE_TRACK]   i_prompt_k,
    output wire [`ACC_RANGE_TRACK]   q_prompt_k,
    output wire [`W_DF_RANGE]        w_df_k,
    //Acquisition results.
    output wire                      acquisition_complete,
    output wire [`I2Q2_RANGE]        acq_peak_i2q2,
    output wire [`DOPPLER_INC_RANGE] acq_peak_doppler,
    output wire [`CS_RANGE]          acq_peak_code_shift,
    //Accumulation debug.
    output wire [`ACC_RANGE]         accumulator_i,
    output wire [`ACC_RANGE]         accumulator_q,
    //Debug signals.
    output wire                      data_available,
    output wire                      track_feed_complete,
    output wire [`SAMPLE_COUNT_RANGE] sample_count,
    output wire [2:0]                 carrier_i,
    output wire [2:0]                 carrier_q,
    output wire                      ca_bit,
    output wire                      ca_clk,
    output wire [9:0]                ca_code_shift);

   //Clock domain crossing.
   `KEEP wire clk_sample_sync;
   synchronizer input_clk_sync(.clk(clk),
                               .in(clk_sample),
                               .out(clk_sample_sync));
   
   `KEEP wire sample_valid_sync;
   synchronizer input_sample_valid_sync(.clk(clk),
                                        .in(sample_valid),
                                        .out(sample_valid_sync));
   
   `KEEP wire feed_reset_sync;
   synchronizer input_feed_reset_sync(.clk(clk),
                                      .in(feed_reset),
                                      .out(feed_reset_sync));
   
   `KEEP wire feed_complete_sync;
   synchronizer input_feed_complete_sync(.clk(clk),
                                         .in(feed_complete),
                                         .out(feed_complete_sync));
   
   `KEEP wire [`INPUT_RANGE] data_sync;
   synchronizer #(.WIDTH(`INPUT_WIDTH))
     input_data_sync(.clk(clk),
                     .in(data),
                     .out(data_sync));

   //Data available strobe.
   //`KEEP wire data_available;
`ifndef HIGH_SPEED
   wire new_sample;
   strobe data_available_strobe(.clk(clk),
                                .reset(global_reset),
                                .in(clk_sample_sync),
                                .out(new_sample));
   assign data_available = new_sample && sample_valid_sync;
`else
   reg data_done;
   always @(posedge clk) begin
      data_done <= global_reset || feed_reset_sync ? 1'b0 :
                   feed_complete_sync ? 1'b1 :
                   data_done;
   end
   assign data_available = !(global_reset || feed_reset_sync) && !data_done;
`endif

   ///////////////
   // Channel 0
   ///////////////
   
   //Channel history.
   wire [`IQ_RANGE]           iq_prompt_km1;
   wire [`ACC_RANGE_TRACK]    i_prompt_km1;
   wire [`ACC_RANGE_TRACK]    q_prompt_km1;
   wire [`W_DF_DOT_RANGE]     w_df_dot_k;
   //Tracking results.
   wire [`IQ_RANGE]           iq_prompt_k;
   wire [`DOPPLER_INC_RANGE]  doppler_inc_kp1;
   wire [`W_DF_RANGE]         w_df_kp1;
   wire [`W_DF_DOT_RANGE]     w_df_dot_kp1;
   wire [`CA_PHASE_INC_RANGE] ca_dphi_kp1;
   //Misc.
   wire accumulator_updating;
   channel channel_0(.clk(clk),
                     .global_reset(global_reset),
                     .mode(mode),
                     //Sample data.
                     .data_available(data_available),
                     .feed_reset(feed_reset_sync),
                     .feed_complete(feed_complete_sync),
                     .data(data_sync),
                     //Code control.
                     .prn(prn),
                     .code_shift(code_shift),
                     //Channel history.
                     .i2q2_valid(i2q2_valid),
                     .i2q2_early(i2q2_early),
                     .i2q2_prompt(i2q2_prompt),
                     .i2q2_late(i2q2_late),
                     .iq_prompt_km1(iq_prompt_km1),
                     .i_prompt_k(i_prompt_k),
                     .q_prompt_k(q_prompt_k),
                     .i_prompt_km1(i_prompt_km1),
                     .q_prompt_km1(q_prompt_km1),
                     .w_df_k(w_df_k),
                     .w_df_dot_k(w_df_dot_k),
                     //Tracking results.
                     .tracking_ready(tracking_ready),
                     .iq_prompt_k(iq_prompt_k),
                     .doppler_inc_kp1(doppler_inc_kp1),
                     .w_df_kp1(w_df_kp1),
                     .w_df_dot_kp1(w_df_dot_kp1),
                     .ca_dphi_kp1(ca_dphi_kp1),
                     //Acquisition results.
                     .acquisition_complete(acquisition_complete),
                     .acq_peak_i2q2(acq_peak_i2q2),
                     .acq_peak_doppler(acq_peak_doppler),
                     .acq_peak_code_shift(acq_peak_code_shift),
                     //Accumulation debug.
                     .accumulator_updating(accumulator_updating),
                     .accumulator_i(accumulator_i),
                     .accumulator_q(accumulator_q),
                     //Debug outputs.
                     .track_feed_complete(track_feed_complete),
                     .sample_count(sample_count),
                     .carrier_i(carrier_i),
                     .carrier_q(carrier_q),
                     .ca_bit(ca_bit),
                     .ca_clk(ca_clk),
                     .ca_code_shift(ca_code_shift));

   ////////////////////
   // Tracking Loops
   ////////////////////

   tracking_loops loops_0(.clk(clk),
                          .reset(global_reset),
                          //Channel 0 history.
                          .i2q2_valid_0(i2q2_valid),
                          .i2q2_early_k_0(i2q2_early),
                          .i2q2_prompt_k_0(i2q2_prompt),
                          .i2q2_late_k_0(i2q2_late),
                          .iq_prompt_km1_0(iq_prompt_km1),
                          .i_prompt_k_0(i_prompt_k),
                          .q_prompt_k_0(q_prompt_k),
                          .i_prompt_km1_0(i_prompt_km1),
                          .q_prompt_km1_0(q_prompt_km1),
                          .w_df_k_0(w_df_k),
                          .w_df_dot_k_0(w_df_dot_k),
                          //Channel 0 tracking results.
                          .tracking_ready_0(tracking_ready),
                          .iq_prompt_k_0(iq_prompt_k),
                          .doppler_inc_kp1_0(doppler_inc_kp1),
                          .w_df_kp1_0(w_df_kp1),
                          .w_df_dot_kp1_0(w_df_dot_kp1),
                          .ca_dphi_kp1_0(ca_dphi_kp1));
   
endmodule