`include "../components/global.vh"
`include "top__channel.vh"
`include "../components/channel__tracking_loops.vh"

`define DEBUG
`include "../components/debug.vh"

`include "../components/subchannel.vh"

module top(
    input                            clk,
    input                            global_reset,
    input [`MODE_RANGE]              mode,
    input                            mem_mode,
    //Sample data.
    input                            clk_sample,
    input                            sample_valid,
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
    output wire [`W_DF_DOT_RANGE]    w_df_dot_k,
           
    output wire [`DOPPLER_INC_RANGE] carrier_dphi_k,
    output wire [`CA_PHASE_INC_RANGE] ca_dphi_k,
    output wire [`SAMPLE_COUNT_TRACK_RANGE] tau_prime_k,
    //Acquisition results.
    output wire                      acquisition_complete,
    output wire [`I2Q2_RANGE]        acq_peak_i2q2,
    output wire [`DOPPLER_INC_RANGE] acq_peak_doppler,
    output wire [`CS_RANGE]          acq_peak_code_shift,
    //Accumulation debug.
    output wire [`ACC_RANGE]         accumulator_i,
    output wire [`ACC_RANGE]         accumulator_q,
    //Debug signals.
    input                            track_carrier_en,
    input                            track_code_en,
    output reg [31:0]                sample_count,
    output wire [3:0]                track_count,
    output reg                       data_available,
    output wire                      track_feed_complete,
    output wire                      ca_bit,
    output wire                      ca_clk,
    output wire [9:0]                ca_code_shift);

   ///////////////////////////////////
   // Clock Domain Synchronization
   ///////////////////////////////////

   //Clock domain crossing usiung a mux synchronizer,
   //triggered on the sample clock edge.
   `KEEP wire clk_sample_sync;
   synchronizer input_clk_sync(.clk(clk),
                               .in(clk_sample),
                               .out(clk_sample_sync));

   //Data available strobe.
   wire sample_edge;
   strobe data_available_strobe(.clk(clk),
                                .reset(global_reset),
                                .in(clk_sample_sync),
                                .out(sample_edge));

   //Delay data available strobe to establish
   //hold time and ensure that all data bits
   //are stable before using them.
   wire new_sample;
   delay #(.DELAY(2))
     sync_hold_delay(.clk(clk),
                     .reset(global_reset),
                     .in(sample_edge),
                     .out(new_sample));

   `PRESERVE reg [`INPUT_RANGE] data_sync;
   always @(posedge clk) begin
      if(new_sample) begin
         data_sync <= data;
         data_available <= sample_valid;
      end
      else begin
         data_available <= 1'b0;
      end
   end

   always @(posedge clk) begin
      sample_count <= global_reset ? 32'd0 :
                      data_available ? sample_count+32'd1 :
                      sample_count;
   end

   ///////////////
   // Memory Bank
   ///////////////

   //Memory bank.
   `KEEP wire mem_bank_ready;
   `KEEP wire mem_bank_frame_start;
   `KEEP wire mem_bank_frame_end;
   `KEEP wire mem_bank_sample_valid;
   `KEEP wire [`INPUT_RANGE] mem_bank_data;
   mem_bank bank_0(.clk(clk),
                   .reset(global_reset),
                   .mode(mem_mode),
                   .data_available(data_available),
                   .data_in(data_sync),
                   .ready(mem_bank_ready),
                   .frame_start(mem_bank_frame_start),
                   .frame_end(mem_bank_frame_end),
                   .sample_valid(mem_bank_sample_valid),
                   .data_out(mem_bank_data));

   ///////////////
   // Channel 0
   ///////////////
   
   //Channel history.
   wire [`IQ_RANGE]           iq_prompt_km1;
   wire [`ACC_RANGE_TRACK]    i_prompt_km1;
   wire [`ACC_RANGE_TRACK]    q_prompt_km1;
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
                     //Real-time sample interface.
                     .data_available(data_available),
                     .data(data_sync),
                     //Memory bank sample interface.
                     .mem_data_available(mem_bank_sample_valid),
                     .mem_data(mem_bank_data),
                     .frame_start(mem_bank_frame_start),
                     .frame_end(mem_bank_frame_end),
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
                     .carrier_dphi_k(carrier_dphi_k),
                     .ca_dphi_k(ca_dphi_k),
                     .tau_prime_k(tau_prime_k),
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
                     .track_carrier_en(track_carrier_en),
                     .track_code_en(track_code_en),
                     .track_count(track_count),
                     .track_feed_complete(track_feed_complete),
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