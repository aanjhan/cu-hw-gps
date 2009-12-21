// This file is part of the Cornell University Hardware GPS Receiver Project.
// Copyright (C) 2009 - Adam Shapiro (ams348@cornell.edu)
//                      Tom Chatt (tjc42@cornell.edu)
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
`include "global.vh"
`include "tracking_loops.vh"
`include "channel__dll.vh"
`include "channel__tracking_loops.vh"

`include "channel.vh"

`define DEBUG
`include "debug.vh"

module tracking_loops_sw(
    input                    clk,
    input                    reset,
    //Channel 0 initizliation.
    input                    init_0,
    input [1:0]              init_tag_0,
    input [`DOPPLER_INC_RANGE] init_carrier_dphi_0,
    //Channel 0 accumulation results.
    input                    acc_valid_0,
    input [1:0]              acc_tag_0,
    input [`ACC_RANGE_TRACK] i_early_0,
    input [`ACC_RANGE_TRACK] q_early_0,
    input [`ACC_RANGE_TRACK] i_prompt_0,
    input [`ACC_RANGE_TRACK] q_prompt_0,
    input [`ACC_RANGE_TRACK] i_late_0,
    input [`ACC_RANGE_TRACK] q_late_0,
    //Channel 0 tracking result memory.
    output wire [1:0]        track_mem_addr_0,
    output wire              track_mem_wr_en_0,
    output wire [52:0]       track_mem_data_0,
    //Debug signals.
    output wire        ready_dbg,
    output reg [`ACC_RANGE_TRACK]   i_prompt_dbg,
    output reg [`ACC_RANGE_TRACK]   q_prompt_dbg,
    output reg [`DOPPLER_INC_RANGE] doppler_inc_dbg,
    output reg [`W_DF_RANGE]        w_df_dbg,
    output reg [`W_DF_DOT_RANGE]    w_df_dot_dbg,
    output reg [`CA_PHASE_INC_RANGE]     ca_dphi_dbg,
    output reg [`DLL_TAU_RANGE]     tau_prime_dbg,
    output reg [`I2Q2_RANGE]        i2q2_early_dbg,
    output reg [`I2Q2_RANGE]        i2q2_prompt_dbg,
    output reg [`I2Q2_RANGE]        i2q2_late_dbg,
    input                           track_carrier_en,
    input                           track_code_en);

   //Store channel 0 I/Q results as they become
   //available, along with result tag.
   //FIXME Ranges.
   `KEEP wire iq_fifo_empty_0;
   wire iq_read_0;
   wire [115:0] results_0;
   tracking_iq_fifo #(.WIDTH(6*`ACC_WIDTH_TRACK+2),
                      .DEPTH(4))
     iq_fifo_0(.clock(clk),
	       .sclr(reset),
	       .wrreq(acc_valid_0),
	       .data({acc_tag_0,
                      i_early_0,q_early_0,
                      i_prompt_0,q_prompt_0,
                      i_late_0,q_late_0}),
	       .rdreq(iq_read_0),
	       .empty(iq_fifo_empty_0),
	       .q(results_0));

   //Store channel 0 I/Q results as they become
   //available, along with result tag.
   //FIXME Ranges.
   `KEEP wire init_fifo_empty;
   wire init_read;
   wire [(`DOPPLER_INC_WIDTH+1):0] init_out;
   tracking_iq_fifo #(.WIDTH(2+`DOPPLER_INC_WIDTH),
                      .DEPTH(4))
     init_fifo(.clock(clk),
	       .sclr(reset),
	       .wrreq(init_0),
	       .data({init_tag_0,init_carrier_dphi_0}),
	       .rdreq(init_read),
	       .empty(init_fifo_empty),
	       .q(init_out));

   wire [1:0] init_tag;
   wire [`DOPPLER_INC_RANGE] init_carrier_dphi;
   assign init_tag = init_out[(`DOPPLER_INC_WIDTH+1):`DOPPLER_INC_WIDTH];
   assign init_carrier_dphi = init_out[`DOPPLER_INC_RANGE];

   //Extract next I/Q results from FIFO.
   //FIXME Ranges.
   wire [1:0] tag_0;
   wire [`ACC_RANGE_TRACK] i_e_0;
   wire [`ACC_RANGE_TRACK] q_e_0;
   wire [`ACC_RANGE_TRACK] i_p_0;
   wire [`ACC_RANGE_TRACK] q_p_0;
   wire [`ACC_RANGE_TRACK] i_l_0;
   wire [`ACC_RANGE_TRACK] q_l_0;
   assign tag_0 = results_0[115:114];
   assign i_e_0 = results_0[113:95];
   assign q_e_0 = results_0[94:76];
   assign i_p_0 = results_0[75:57];
   assign q_p_0 = results_0[56:38];
   assign i_l_0 = results_0[37:19];
   assign q_l_0 = results_0[18:0];

   /////////////////////////
   // Begin Tracking Update
   /////////////////////////

   //FIXME Select channel via round-robin.
   `KEEP wire [1:0]             tag;
   `KEEP wire [`ACC_RANGE_TRACK] i_e;
   `KEEP wire [`ACC_RANGE_TRACK] q_e;
   `KEEP wire [`ACC_RANGE_TRACK] i_p;
   `KEEP wire [`ACC_RANGE_TRACK] q_p;
   `KEEP wire [`ACC_RANGE_TRACK] i_l;
   `KEEP wire [`ACC_RANGE_TRACK] q_l;
   `KEEP wire                    iq_read;
   assign tag = tag_0;
   assign i_e = i_e_0;
   assign q_e = q_e_0;
   assign i_p = i_p_0;
   assign q_p = q_p_0;
   assign i_l = i_l_0;
   assign q_l = q_l_0;
   assign iq_read_0 = iq_read;

   //Store I/Q prompt values for tracking loops.
   //Note: This only works for serialized updates.
   //      These values should be pipelined, or
   //      placed in a FIFO if the tracking loops
   //      are parallelized.
   reg [`ACC_RANGE_TRACK] i_prompt_k;
   reg [`ACC_RANGE_TRACK] q_prompt_k;
   always @(posedge clk) begin
      i_prompt_k <= reset ? `ACC_WIDTH_TRACK'd0 :
                    iq_read ? i_p :
                    i_prompt_k;
      
      q_prompt_k <= reset ? `ACC_WIDTH_TRACK'd0 :
                    iq_read ? q_p :
                    q_prompt_k;
   end

   //Start a new tracking update when one is
   //not already in progress, and I/Q results
   //are available from a channel/slot.
   reg tracking_active;
   `KEEP wire start_tracking_update;
   assign start_tracking_update = !tracking_active && !iq_fifo_empty_0;

   //Flag when a tracking update begins.
   //Currently tracking updates are serialized
   //such that only one can occur at a time.
   wire tracking_update_complete;
   always @(posedge clk) begin
      tracking_active <= reset ? 1'b0 :
                         tracking_update_complete ? 1'b0 :
                         start_tracking_update ? 1'b1 :
                         tracking_active;
   end

   ////////////////////
   // Compute I^2+Q^2
   ////////////////////

   //Square I and Q for each subchannel.
   `KEEP wire start_square;
   reg [1:0] sub_select;
   assign start_square = sub_select!=2'h3;

   //Issue a read to the channel FIFO to discard
   //I/Q values when the last calculation has started.
   assign iq_read = start_square && sub_select==2'h2;
   
   always @(posedge clk) begin
      sub_select <= reset ? 2'h3 :
                    start_tracking_update ? 2'h0 :
                    sub_select!=2'h3 ? sub_select+2'h1 :
                    sub_select;
   end

   //Take the absolute value of I/Q to
   //reduce multiplier complexity.
   wire [`ACC_MAG_RANGE] i_mag;
   abs #(.WIDTH(`ACC_WIDTH_TRACK))
     abs_i(.in(sub_select==2'h0 ? i_e :
               sub_select==2'h1 ? i_p :
               i_l),
           .out(i_mag));

   wire [`ACC_MAG_RANGE] q_mag;
   abs #(.WIDTH(`ACC_WIDTH_TRACK))
     abs_q(.in(sub_select==2'h0 ? q_e :
               sub_select==2'h1 ? q_p :
               q_l),
           .out(q_mag));

   //Square I and Q values.
   `KEEP wire [`I2Q2_RANGE] i2;
   iq_square #(.INPUT_WIDTH(`ACC_MAG_WIDTH),
               .OUTPUT_WIDTH(`I2Q2_WIDTH))
     i2_square(.clock(clk),
               .dataa(i_mag),
               .result(i2));
   
   `KEEP wire [`I2Q2_RANGE] q2;
   iq_square #(.INPUT_WIDTH(`ACC_MAG_WIDTH),
               .OUTPUT_WIDTH(`I2Q2_WIDTH))
     q2_square(.clock(clk),
               .dataa(q_mag),
               .result(q2));

   //Pipe square results for timing.
   `KEEP wire [`I2Q2_RANGE] i2_km1;
   delay #(.WIDTH(`I2Q2_WIDTH))
     i2_delay(.clk(clk),
              .reset(reset),
              .in(i2),
              .out(i2_km1));

   `KEEP wire [`I2Q2_RANGE] q2_km1;
   delay #(.WIDTH(`I2Q2_WIDTH))
     q2_delay(.clk(clk),
              .reset(reset),
              .in(q2),
              .out(q2_km1));

   //Sum squared values.
   wire [`I2Q2_RANGE] i2q2_out;
   assign i2q2_out = i2_km1+q2_km1;

   //Flag i2q2_ready when multiply and sum have
   //completed, noting iq_square multiplier
   //pipeline depth.
   `KEEP wire i2q2_ready;
   delay #(.DELAY(4+1))
     square_ready_delay(.clk(clk),
                        .reset(reset),
                        .in(start_square),
                        .out(i2q2_ready));

   //Pipe slot+channel tag along with i2q2 computation.
   //FIXME Can this be reduced with multi-cycle flop stages?
   wire [1:0] tag_post_i2q2;
   delay #(.DELAY(4+1))
     square_tag_delay(.clk(clk),
                      .reset(reset),
                      .in(tag),
                      .out(tag_post_i2q2));

   reg [1:0]         i2q2_select;
   reg [1:0]         i2q2_tag;
   reg [`I2Q2_RANGE] i2q2_early;
   reg [`I2Q2_RANGE] i2q2_prompt;
   reg [`I2Q2_RANGE] i2q2_late;
   always @(posedge clk) begin
      i2q2_select <= reset ? 2'h0 :
                     i2q2_ready ? (i2q2_select!=2'd2 ?
                                   i2q2_select+2'd1 :
                                   2'd0) :
                     i2q2_select;

      i2q2_tag <= i2q2_ready && i2q2_select==2'd0 ? tag_post_i2q2 : i2q2_tag;
      i2q2_early <= i2q2_ready && i2q2_select==2'd0 ? i2q2_out : i2q2_early;
      i2q2_prompt <= i2q2_ready && i2q2_select==2'd1 ? i2q2_out : i2q2_prompt;
      i2q2_late <= i2q2_ready && i2q2_select==2'd2 ? i2q2_out : i2q2_late;
   end

   `KEEP wire sqrt_starting;
   `PRESERVE reg sqrt_pending;
   always @(posedge clk) begin
      sqrt_pending <= reset ? 1'b0 :
                      i2q2_ready && i2q2_select==2'd2 ? 1'b1 :
                      sqrt_starting ? 1'b0 :
                      sqrt_pending;
   end
   
   ////////////////////
   // IQ Computation
   ////////////////////

   //Compute IQ values for selected channel.
   wire             iq_early_start;
   wire             iq_early_ready;
   wire [`IQ_RANGE] iq_early_k_value;
   wire             sq_early_in_use;
   sqrt_fixed sqrt_early(.clk(clk),
                         .reset(reset),
                         .input_ready(sqrt_pending),
                         .in(i2q2_early[`I2Q2_RANGE_TRACK]),
                         .flag_new_input(iq_early_start),
                         .output_ready(iq_early_ready),
                         .in_use(sq_early_in_use),
                         .out(iq_early_k_value));

   wire             iq_prompt_start;
   wire             iq_prompt_ready;
   wire [`IQ_RANGE] iq_prompt_k_value;
   wire             sq_prompt_in_use;
   sqrt_fixed sqrt_prompt(.clk(clk),
                          .reset(reset),
                          .input_ready(sqrt_pending),
                          .in(i2q2_prompt[`I2Q2_RANGE_TRACK]),
                          .flag_new_input(iq_prompt_start),
                          .output_ready(iq_prompt_ready),
                          .in_use(sq_prompt_in_use),
                          .out(iq_prompt_k_value));

   wire             iq_late_start;
   wire             iq_late_ready;
   wire [`IQ_RANGE] iq_late_k_value;
   wire             sq_late_in_use;
   sqrt_fixed sqrt_late(.clk(clk),
                        .reset(reset),
                        .input_ready(sqrt_pending),
                        .in(i2q2_late[`I2Q2_RANGE_TRACK]),
                        .flag_new_input(iq_late_start),
                        .output_ready(iq_late_ready),
                        .in_use(sq_late_in_use),
                        .out(iq_late_k_value));

   //Note: All square root functions are synchronized.
   //      They all should start at the same time.
   assign sqrt_starting = iq_prompt_start;

   //Note: All square root functions are synchronized.
   //      They all should finish at the same time.
   `KEEP wire iq_values_ready;
   assign iq_values_ready = iq_prompt_ready;

   //Store IQ values returned by square roots.
   reg [1:0] iq_tag;//FIXME Range.
   reg [`IQ_RANGE] iq_early_k;
   reg [`IQ_RANGE] iq_prompt_k;
   reg [`IQ_RANGE] iq_late_k;
   always @(posedge clk) begin
      iq_tag <= reset ? 2'd0 :
                iq_values_ready ? i2q2_tag :
                iq_tag;
      
      iq_early_k <= reset ? `IQ_WIDTH'h0 :
                    iq_values_ready ? iq_early_k_value :
                    iq_early_k;
      
      iq_prompt_k <= reset ? `IQ_WIDTH'h0 :
                     iq_values_ready ? iq_prompt_k_value :
                     iq_prompt_k;
      
      iq_late_k <= reset ? `IQ_WIDTH'h0 :
                   iq_values_ready ? iq_late_k_value :
                   iq_late_k;
   end // always @ (posedge clk)
   
   ////////////////////
   // Tracking Loops
   ////////////////////

   //The history memory holds the history values
   //for ALL channels and slots. It is addressed
   //by tracking tag ({channel,slot}).
   //FIXME Defines/ranges.
   `KEEP wire [1:0]  hist_rd_addr;
   `KEEP wire [1:0]  hist_wr_addr;
   `KEEP wire        hist_wr_en;
   `KEEP wire [106:0] hist_in;
   `KEEP wire [106:0] hist_out;
   tracking_hist_ram #(.ADDR_WIDTH(2),
                       .DATA_WIDTH(107))
     history_ram(.clock(clk),
                 .rdaddress(hist_rd_addr),
                 .data(hist_in),
                 .wraddress(hist_wr_addr),
                 .wren(hist_wr_en),
                 .q(hist_out));

   //Initialize the next slot as soon as the tracking
   //loops become idle.
   wire init_next_slot;
   assign init_next_slot = dll_result_ready && !init_fifo_empty;
   
   //Ignore the first tracking update for a given
   //slot, in order to collect the two accumulations
   //needed for carrier tracking.
   //FIXME Ranges.
   reg [1:0] ignore_first_update;
   generate
      genvar i;
      for(i=0;i<1;i=i+1) begin : ignore_gen
         always @(posedge clk) begin
            ignore_first_update[i] <= reset ? 1'b0 :
                                      init_next_slot && init_tag==i ? 1'b1 :
                                      tracking_update_complete && dll_result_tag==i ? 1'b0 :
                                      ignore_first_update[i];
         end
      end
   endgenerate

   //Issue a read for the history values for the
   //tag that has completed sqrt.
   //Note: The M4K takes 2 cycles to read.
   assign hist_rd_addr = iq_tag;

   //Decode history results.
   //Note: i_prompt_k and q_prompt_k are stored
   //      above, and are only valid if the tracking
   //      updates are serialized.
   `KEEP wire [`IQ_RANGE]        iq_prompt_km1;
   `KEEP wire [`ACC_RANGE_TRACK] i_prompt_km1;
   `KEEP wire [`ACC_RANGE_TRACK] q_prompt_km1;
   `KEEP wire [`W_DF_RANGE]      w_df_k;
   `KEEP wire [`W_DF_DOT_RANGE]  w_df_dot_k;
   assign iq_prompt_km1 = hist_out[106:89];
   assign i_prompt_km1 = hist_out[88:70];
   assign q_prompt_km1 = hist_out[69:51];
   assign w_df_k = hist_out[50:25];
   assign w_df_dot_k = hist_out[24:0];
   
   //Delay start of tracking loops by two cycles
   //to allow history memory read to complete.
   `KEEP wire start_loops;
   delay #(.DELAY(3))
     loop_start_delay(.clk(clk),
                      .reset(reset),
                      .in(iq_values_ready),
                      .out(start_loops));
   
   //Assert start to each loop until accepted.
   `KEEP wire          fll_starting;
   `KEEP wire          dll_starting;
   `PRESERVE reg [1:0] loop_start_status;
   always @(posedge clk) begin
      loop_start_status <= reset ? 2'h0 :
                           start_loops ? 2'b11 :
                           fll_starting ? loop_start_status & ~2'b10 :
                           dll_starting ? loop_start_status & ~2'b01 :
                           loop_start_status;
   end

   //Frequency-locked loop.
   //FIXME Connect iq_tag to tag port.
   `KEEP wire                      fll_result_ready;
   `KEEP wire [`CHANNEL_ID_RANGE]  fll_result_tag;
   `KEEP wire [`DOPPLER_INC_RANGE] doppler_inc_out;
   `KEEP wire [`W_DF_RANGE]        w_df_kp1;
   `KEEP wire [`W_DF_DOT_RANGE]    w_df_dot_kp1;
   fll fll0(.clk(clk),
            .reset(reset),
            .start(loop_start_status[1]),
            .tag(`CHANNEL_ID_WIDTH'd0),
            .starting(fll_starting),
            .iq_prompt_k(iq_prompt_k),
            .iq_prompt_km1(iq_prompt_km1),
            .i_prompt_k(i_prompt_k),
            .q_prompt_k(q_prompt_k),
            .i_prompt_km1(i_prompt_km1),
            .q_prompt_km1(q_prompt_km1),
            .w_df_k(w_df_k),
            .w_df_dot_k(w_df_dot_k),
            .result_ready(fll_result_ready),
            .result_tag(fll_result_tag),
            .doppler_inc_kp1(doppler_inc_out),
            .w_df_kp1(w_df_kp1),
            .w_df_dot_kp1(w_df_dot_kp1));
   
   `KEEP wire [`DOPPLER_INC_RANGE] doppler_inc_kp1;
   assign doppler_inc_kp1 = track_carrier_en ? doppler_inc_out : `DOPPLER_INC_WIDTH'd0;

   //Delay-locked loop.
   //FIXME Connect iq_tag to tag port.
   `KEEP wire                     dll_result_ready;
   `KEEP wire [`CHANNEL_ID_RANGE] dll_result_tag;
   `KEEP wire [`DLL_DPHI_RANGE]   dll_dphi_out;
   `KEEP wire [`DLL_TAU_RANGE]    tau_prime_out;
   `KEEP wire                     w_df_ready;
   wire [`W_DF_RANGE]             w_df_kp1_to_dll;
   dll dll0(.clk(clk),
            .reset(reset),
            .start(loop_start_status[0]),
            .tag(`CHANNEL_ID_WIDTH'd0),
            .starting(dll_starting),
            .iq_early(iq_early_k),
            .iq_late(iq_late_k),
            .w_df_ready(w_df_ready),
            .w_df_kp1(w_df_kp1_to_dll),
            .result_ready(dll_result_ready),
            .result_tag(dll_result_tag),
            .ca_dphi(dll_dphi_out),
            .tau_prime(tau_prime_out));
   
   `KEEP wire [`DLL_DPHI_RANGE] dll_dphi_kp1;
   `KEEP wire [`DLL_TAU_RANGE]  tau_prime_kp1;
   assign dll_dphi_kp1 = track_code_en ? dll_dphi_out : `DLL_DPHI_WIDTH'd0;
   assign tau_prime_kp1 = track_code_en ? tau_prime_out : `DLL_TAU_WIDTH'd0;

   //Sign-extend DLL phase increment to CA increment width.
   //FIXME Remove this and resize ca_dphi in DLL.
   `KEEP wire [`CA_PHASE_INC_RANGE] ca_dphi_kp1;
   assign ca_dphi_kp1 = {{(`CA_PHASE_INC_WIDTH-`DLL_DPHI_WIDTH){dll_dphi_kp1[`DLL_DPHI_WIDTH-1]}},dll_dphi_kp1};

   ////////////////////
   // Report Results
   ////////////////////

   //Inform DLL of Doppler calculation completion.
   `KEEP reg fll_finished;
   assign w_df_ready = fll_result_ready || fll_finished;

   `KEEP reg [`W_DF_RANGE] w_df_kp1_hold;
   assign w_df_kp1_to_dll = fll_result_ready ? w_df_kp1 : w_df_kp1_hold;

   //Store Doppler control until DLL has completed
   //in order to write control parameters to memory.
   `KEEP reg [`DOPPLER_INC_RANGE] doppler_inc_kp1_hold;
   always @(posedge clk) begin
      fll_finished <= start_loops ? 1'b0 :
                      fll_result_ready ? 1'b1 :
                      fll_finished;
      w_df_kp1_hold <= fll_result_ready ? w_df_kp1 : w_df_kp1_hold;
      doppler_inc_kp1_hold <= fll_result_ready ? doppler_inc_kp1 : doppler_inc_kp1_hold;
   end // always @ (posedge clk)

   //Store history results in M4K.
   //Initialize new slots when idle and initialization is necessary.
   //FIXME Ranges.
   //FIXME Initialize slot values when idle (get w_df value from acq).
   assign hist_wr_en = (fll_result_ready && !ignore_first_update[fll_result_tag]) ||
                       !init_fifo_empty;
   assign hist_wr_addr = fll_result_ready ? fll_result_tag : init_tag;
   assign hist_in[106:89] = fll_result_ready ? iq_prompt_k : `IQ_WIDTH'd1;
   assign hist_in[88:70] = fll_result_ready ? i_prompt_k : `ACC_WIDTH_TRACK'd1;
   assign hist_in[69:51] = fll_result_ready ? q_prompt_k : `ACC_WIDTH_TRACK'd1;
   assign hist_in[50:25] = fll_result_ready ? w_df_kp1 : (init_carrier_dphi<<`ANGLE_SHIFT);
   assign hist_in[24:0] = fll_result_ready ? w_df_dot_kp1 : `W_DF_DOT_WIDTH'd0;
   assign init_read = hist_wr_en && !fll_result_ready;
   
   //Update slot control parameters.
   //FIXME Ranges.
   assign track_mem_addr_0 = dll_result_tag[1:0];//FIXME Select only the slot ID for this channel.
   assign track_mem_wr_en_0 = (dll_result_ready && !ignore_first_update[dll_result_tag]);
   assign track_mem_data_0[52:38] = tau_prime_kp1;
   assign track_mem_data_0[37:17] = ca_dphi_kp1;
   assign track_mem_data_0[16:0] = doppler_inc_kp1_hold;

   //Assert tracking_update_complete to the top.
   assign tracking_update_complete = dll_result_ready;

   //Debug outputs.
   wire dbg_update;
   assign dbg_update = tracking_update_complete && iq_tag==0;
   
   delay dbg_delay(.clk(clk),
                   .reset(reset),
                   .in(dbg_update),
                   .out(ready_dbg));
   
   always @(posedge clk) begin
      if(hist_wr_en && iq_tag==0) begin
         i_prompt_dbg <= i_prompt_k;
         q_prompt_dbg <= q_prompt_k;
         doppler_inc_dbg <= doppler_inc_kp1;
         w_df_dbg <= w_df_kp1;
         w_df_dot_dbg <= w_df_dot_kp1;
         i2q2_early_dbg <= i2q2_early;
         i2q2_prompt_dbg <= i2q2_prompt;
         i2q2_late_dbg <= i2q2_late;
      end
      if(track_mem_wr_en_0 && iq_tag==0) begin
         ca_dphi_dbg <= ca_dphi_kp1;
         tau_prime_dbg <= tau_prime_kp1;
      end
   end
   
endmodule