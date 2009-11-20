`include "../components/global.vh"
//`include "top__channel.vh"
`include "../components/channel__tracking_loops.vh"

`include "../components/channel.vh"
`include "../components/tracking_loops.vh"

`define DEBUG
`include "../components/debug.vh"

`include "../components/subchannel.vh"

module top(
    input                            clk,
    input                            global_reset,
    //Sample data.
    input                            clk_sample,
    input                            sample_valid,
    input [`INPUT_RANGE]             data,
    //Init control.
    input                            init,
    input [`PRN_RANGE]               prn,
    //Tracking results.
    output wire                      tracking_ready,
    output wire [`I2Q2_RANGE]        i2q2_early,
    output wire [`I2Q2_RANGE]        i2q2_prompt,
    output wire [`I2Q2_RANGE]        i2q2_late,
    output wire [`ACC_RANGE_TRACK]   i_prompt_k,
    output wire [`ACC_RANGE_TRACK]   q_prompt_k,
    output wire [`W_DF_RANGE]        w_df_k,
    output wire [`W_DF_DOT_RANGE]    w_df_dot_k,
    output wire [`DOPPLER_INC_RANGE] carrier_dphi_k,
    output wire [`CA_PHASE_INC_RANGE] ca_dphi_k,
    output wire [`SAMPLE_COUNT_TRACK_RANGE] tau_prime_k,
    //Debug signals.
    input                            track_carrier_en,
    input                            track_code_en);

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
   `PRESERVE reg data_available;
   always @(posedge clk) begin
      if(new_sample) begin
         data_sync <= data;
         data_available <= sample_valid;
      end
      else begin
         data_available <= 1'b0;
      end
   end

   ///////////////
   // Channel 0
   ///////////////

   //Accumulation results.
   wire              acc_valid;
   wire [1:0]        acc_tag;
   wire [`ACC_RANGE] i_early;
   wire [`ACC_RANGE] q_early;
   wire [`ACC_RANGE] i_prompt;
   wire [`ACC_RANGE] q_prompt;
   wire [`ACC_RANGE] i_late;
   wire [`ACC_RANGE] q_late;
   //Tracking memory.
   wire [1:0]          track_mem_addr;
   wire                track_mem_wr_en;
   wire [52:0]         track_mem_data_in;
   wire [52:0]         track_mem_data_out;
   //Misc.
   wire accumulator_updating;
   wire slot_initializing;
   channel_sw channel_0(.clk(clk),
                        .reset(global_reset),
                        //Real-time sample interface.
                        .data_available(data_available),
                        .data(data_sync),
                        //Slot control.
                        .init(init),
                        .prn(prn),
                        .slot_initializing(slot_initializing),
                        //Accumulation results.
                        .acc_valid(acc_valid),
                        .acc_tag(acc_tag),
                        .i_early(i_early),
                        .q_early(q_early),
                        .i_prompt(i_prompt),
                        .q_prompt(q_prompt),
                        .i_late(i_late),
                        .q_late(q_late),
                        //Tracking results memory interface.
                        .track_mem_addr(track_mem_addr),
                        .track_mem_wr_en(track_mem_wr_en),
                        .track_mem_data_in(track_mem_data_in),
                        .track_mem_data_out(track_mem_data_out));

   ////////////////////
   // Tracking Loops
   ////////////////////

   tracking_loops_sw loops_0(.clk(clk),
                             .reset(global_reset),
                             //Accumulation results.
                             .acc_valid_0(acc_valid),
                             .acc_tag_0(acc_tag),
                             .i_early_0(i_early[`ACC_RANGE_TRACK]),
                             .q_early_0(q_early[`ACC_RANGE_TRACK]),
                             .i_prompt_0(i_prompt[`ACC_RANGE_TRACK]),
                             .q_prompt_0(q_prompt[`ACC_RANGE_TRACK]),
                             .i_late_0(i_late[`ACC_RANGE_TRACK]),
                             .q_late_0(q_late[`ACC_RANGE_TRACK]),
                             //Tracking results memory interface.
                             .track_mem_addr_0(track_mem_addr),
                             .track_mem_wr_en_0(track_mem_wr_en),
                             .track_mem_data_in_0(track_mem_data_in),
                             .track_mem_data_out_0(track_mem_data_out),
                             //Debug.
                             .ready_dbg(tracking_ready),
                             .i2q2_early_dbg(i2q2_early),
                             .i2q2_prompt_dbg(i2q2_prompt),
                             .i2q2_late_dbg(i2q2_late),
                             .i_prompt_dbg(i_prompt_k),
                             .q_prompt_dbg(q_prompt_k),
                             .w_df_dbg(w_df_k),
                             .w_df_dot_dbg(w_df_dot_k),
                             .doppler_inc_dbg(carrier_dphi_k),
                             .ca_dphi_dbg(ca_dphi_k),
                             .tau_prime_dbg(tau_prime_k),
                             .track_carrier_en(track_carrier_en),
                             .track_code_en(track_code_en));
   
endmodule