`include "../components/global.vh"
//`include "top__channel.vh"
`include "../components/channel__tracking_loops.vh"

`include "../components/channel.vh"
`include "../components/tracking_loops.vh"
`include "../components/ca_upsampler.vh"

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
    input                            mem_mode,
    //Acquisition control.
    input                            acq_start,
    input [`PRN_RANGE]               acq_start_prn,

    output wire                      acq_in_progress,
    output wire [`DOPPLER_INC_RANGE] acq_carrier_dphi,
    output wire [`CS_RANGE]          acq_code_shift,
    output wire [`I2Q2_RANGE]        acq_i2q2,
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
    //Accumulation debug.
   output wire              acc_valid,
   output wire [1:0]        acc_tag,
   output wire [`ACC_RANGE] i_early,
   output wire [`ACC_RANGE] q_early,
   output wire [`ACC_RANGE] i_prompt,
   output wire [`ACC_RANGE] q_prompt,
   output wire [`ACC_RANGE] i_late,
   output wire [`ACC_RANGE] q_late,
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

   /////////////////////////
   // Satellite Acquisition
   /////////////////////////

   //wire acq_in_progress;
   `KEEP wire acq_complete;
   wire satellite_acquired;
   `KEEP wire [`PRN_RANGE] acq_prn;
   //wire [`DOPPLER_INC_RANGE] acq_carrier_dphi;
   //wire [`CS_RANGE]          acq_code_shift;
   acquisition_unit acq_0(.clk(clk),
                          .reset(global_reset),
                          .mem_data_available(mem_bank_sample_valid),
                          .mem_data(mem_bank_data),
                          .frame_start(mem_bank_frame_start),
                          .frame_end(mem_bank_frame_end),
                          .start(acq_start),
                          .prn(acq_start_prn),
                          .in_progress(acq_in_progress),
                          .acquisition_complete(acq_complete),
                          .satellite_acquired(satellite_acquired),
                          .acq_prn(acq_prn),
                          .acq_peak_doppler(acq_carrier_dphi),
                          .acq_peak_code_shift(acq_code_shift),
                          .acq_peak_i2q2(acq_i2q2));

   ////////////////////
   // Initialization
   ////////////////////

   wire init_fifo_empty;
   wire init_fifo_full;
   wire init_fifo_read;
   wire [(`PRN_WIDTH+`DOPPLER_INC_WIDTH+`CS_WIDTH-1):0] init_fifo_out;
   sync_fifo #(.WIDTH(`PRN_WIDTH+`DOPPLER_INC_WIDTH+`CS_WIDTH),
               .DEPTH(4))
     pending_init_fifo(.clk(clk),
                       .reset(global_reset),
                       .empty(init_fifo_empty),
                       .full(init_fifo_full),
                       .wr_req(satellite_acquired),
                       .wr_data({acq_prn,acq_carrier_dphi,acq_code_shift}),
                       .rd_req(init_fifo_read),
                       .rd_data(init_fifo_out));

   //Extract next available PRN for initialization.
   `KEEP wire [`PRN_RANGE]         init_prn;
   `KEEP wire [`DOPPLER_INC_RANGE] init_carrier_dphi;
   `KEEP wire [`CS_RANGE]          init_code_shift;
   assign init_prn = init_fifo_out[(`PRN_WIDTH+`DOPPLER_INC_WIDTH+`CS_WIDTH-1):(`DOPPLER_INC_WIDTH+`CS_WIDTH)];
   assign init_carrier_dphi = init_fifo_out[(`DOPPLER_INC_WIDTH+`CS_WIDTH-1):`CS_WIDTH];
   assign init_code_shift = init_fifo_out[(`CS_WIDTH-1):0];

   //Start a new initialization whenever there is a
   //new SV pending and there isn't an init pending.
   `KEEP wire ca_init_start;
   reg init_in_progress;
   assign ca_init_start = !init_fifo_empty && !init_in_progress;

   //Run C/A generator until target code shift has
   //been reached, then initialize next slot.
   wire                       init_target_reached;
   wire [`CA_ACC_RANGE]       init_ca_clk_acc;
   wire                       init_ca_clk_hist;
   wire [`CA_CHIP_HIST_RANGE] init_prompt_chip_hist;
   wire [`CA_CHIP_HIST_RANGE] init_late_chip_hist;
   wire [10:1]                init_g1;
   wire [10:1]                init_g2;
   ca_initializer ca_init(.clk(clk),
                          .reset(global_reset || ca_init_start),
                          .prn(init_prn),
                          .seek_target(init_code_shift),
                          .seek_complete(init_target_reached),
                          .ca_clk_acc(init_ca_clk_acc),
                          .ca_clk_hist(init_ca_clk_hist),
                          .prompt_chip_hist(init_prompt_chip_hist),
                          .late_chip_hist(init_late_chip_hist),
                          .g1(init_g1),
                          .g2(init_g2));

   wire slot_initializing_0;
   always @(posedge clk) begin
      init_in_progress <= global_reset ? 1'b0 :
                          ca_init_start ? 1'b1 :
                          slot_initializing_0 ? 1'b0 :
                          init_in_progress;
   end

   `KEEP wire init_ready;
   assign init_ready = init_in_progress && init_target_reached;

   assign init_fifo_read = slot_initializing_0;

   ///////////////
   // Channel 0
   ///////////////

   //Accumulation results.
   /*wire              acc_valid;
   wire [1:0]        acc_tag;
   wire [`ACC_RANGE] i_early;
   wire [`ACC_RANGE] q_early;
   wire [`ACC_RANGE] i_prompt;
   wire [`ACC_RANGE] q_prompt;
   wire [`ACC_RANGE] i_late;
   wire [`ACC_RANGE] q_late;*/
   wire init_track_0;
   wire [1:0] init_track_tag_0;
   wire [`DOPPLER_INC_RANGE] init_track_carrier_dphi_0;
   //Tracking memory.
   wire [1:0]          track_mem_addr_0;
   wire                track_mem_wr_en_0;
   wire [52:0]         track_mem_data_0;
   //Misc.
   wire accumulator_updating;
   channel_sw channel_0(.clk(clk),
                        .reset(global_reset),
                        //Real-time sample interface.
                        .data_available(data_available),
                        .data(data_sync),
                        //Slot initialization.
                        .init_ready(init_ready),
                        .init_prn(init_prn),
                        .init_carrier_dphi(init_carrier_dphi),
                        .init_code_shift(init_code_shift),
                        .init_ca_clk_acc(init_ca_clk_acc),
                        .init_ca_clk_hist(init_ca_clk_hist),
                        .init_prompt_chip_hist(init_prompt_chip_hist),
                        .init_late_chip_hist(init_late_chip_hist),
                        .init_g1(init_g1),
                        .init_g2(init_g2),
                        .slot_initializing(slot_initializing_0),
                        //Tracking loop initialization.
                        .init_track(init_track_0),
                        .init_track_tag(init_track_tag_0),
                        .init_track_carrier_dphi(init_track_carrier_dphi_0),
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
                        .track_mem_addr(track_mem_addr_0),
                        .track_mem_wr_en(track_mem_wr_en_0),
                        .track_mem_data(track_mem_data_0));

   ////////////////////
   // Tracking Loops
   ////////////////////

   tracking_loops_sw loops_0(.clk(clk),
                             .reset(global_reset),
                             //Channel 0 initialization.
                             .init_0(init_track_0),
                             .init_tag_0(init_track_tag_0),
                             .init_carrier_dphi_0(init_track_carrier_dphi_0),
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
                             .track_mem_addr_0(track_mem_addr_0),
                             .track_mem_wr_en_0(track_mem_wr_en_0),
                             .track_mem_data_0(track_mem_data_0),
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