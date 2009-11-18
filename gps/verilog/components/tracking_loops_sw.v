`include "global.vh"
`include "tracking_loops.vh"
`include "channel__dll.vh"
`include "channel__tracking_loops.vh"

`define DEBUG
`include "debug.vh"

module tracking_loops_sw(
    input              clk,
    input              reset,
    //Channel 0 accumulation results.
    input              acc_valid_0,
    input [1:0]        acc_tag_0,
    input [`ACC_RANGE] i_early_0,
    input [`ACC_RANGE] q_early_0,
    input [`ACC_RANGE] i_prompt_0,
    input [`ACC_RANGE] q_prompt_0,
    input [`ACC_RANGE] i_late_0,
    input [`ACC_RANGE] q_late_0,
    //Channel 0 tracking result memory.
    input [1:0]        track_mem_addr_0,
    input              track_mem_wr_en_0,
    input [52:0]       track_mem_data_in_0,
    output wire [52:0] track_mem_data_out_0);

   //Store channel 0 I/Q results as they become
   //available, along with result tag.
   //FIXME Ranges.
   wire iq_fifo_empty_0;
   wire iq_read_0;
   wire [109:0] results_0;
   tracking_iq_fifo #(.WIDTH(6*`ACC_WIDTH+2),
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

   //Extract next I/Q results from FIFO.
   //FIXME Ranges.
   wire [1:0]        tag_0;
   wire [`ACC_RANGE] i_e_0;
   wire [`ACC_RANGE] q_e_0;
   wire [`ACC_RANGE] i_p_0;
   wire [`ACC_RANGE] q_p_0;
   wire [`ACC_RANGE] i_l_0;
   wire [`ACC_RANGE] q_l_0;
   assign tag_0 = results_0[109:108];
   assign i_e_0 = results_0[107:90];
   assign q_e_0 = results_0[89:72];
   assign i_p_0 = results_0[71:54];
   assign q_p_0 = results_0[53:36];
   assign i_l_0 = results_0[35:18];
   assign q_l_0 = results_0[17:0];

   /////////////////////////
   // Begin Tracking Update
   /////////////////////////

   //FIXME Select channel via round-robin.
   wire [1:0]        tag;
   wire [`ACC_RANGE] i_e;
   wire [`ACC_RANGE] q_e;
   wire [`ACC_RANGE] i_p;
   wire [`ACC_RANGE] q_p;
   wire [`ACC_RANGE] i_l;
   wire [`ACC_RANGE] q_l;
   wire              iq_read;
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
   reg [`ACC_RANGE] i_prompt_k;
   reg [`ACC_RANGE] q_prompt_k;
   always @(posedge clk) begin
      i_prompt_k <= reset ? `ACC_WIDTH'd0 :
                    iq_read ? i_p :
                    i_prompt_k;
      
      q_prompt_k <= reset ? `ACC_WIDTH'd0 :
                    iq_read ? q_p :
                    q_prompt_k;
   end

   //Start a new tracking update when one is
   //not already in progress, and I/Q results
   //are available from a channel/slot.
   reg tracking_active;
   wire start_tracking_update;
   assign start_tracking_update = !tracking_active && iq_fifo_empty_0;

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
   wire start_square;
   reg [1:0] sub_select;
   assign start_square = sub_select!=2'h3;

   //Issue a read to the channel FIFO to discard
   //I/Q values when the last calculation has started.
   assign iq_read = start_square && sub_select==2'h2;
   
   always @(posedge clk) begin
      sub_select <= reset ? 2'h0 :
                    start_tracking_update ? 2'h0 :
                    sub_select!=2'h3 ? sub_select+2'h1 :
                    sub_select;
   end

   //Take the absolute value of I/Q to
   //reduce multiplier complexity.
   wire [`ACC_MAG_RANGE] i_mag;
   abs #(.WIDTH(`ACC_WIDTH))
     abs_i(.in(sub_select==2'h0 ? i_e :
               sub_select==2'h1 ? i_p :
               i_l),
           .out(i_mag));

   wire [`ACC_MAG_RANGE] q_mag;
   abs #(.WIDTH(`ACC_WIDTH))
     abs_q(.in(sub_select==2'h0 ? q_e :
               sub_select==2'h1 ? q_p :
               q_l),
           .out(q_mag));

   //Square I and Q values.
   wire [`I2Q2_RANGE] i2;
   iq_square #(.INPUT_WIDTH(`ACC_MAG_WIDTH),
               .OUTPUT_WIDTH(`I2Q2_WIDTH))
     i2_square(.clock(clk),
               .dataa(i_mag),
               .result(i2));
   
   wire [`I2Q2_RANGE] q2;
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
   wire i2q2_ready;
   delay #(.DELAY(5+1))
     square_delay(.clk(clk),
                  .reset(reset),
                  .in(start_square),
                  .out(i2q2_ready));

   //Pipe slot+channel tag along with i2q2 computation.
   //FIXME Can this be reduced with multi-cycle flop stages?
   wire [1:0] tag_post_i2q2;
   delay #(.DELAY(5+1))
     square_delay(.clk(clk),
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
      iq_tag <= reset ? 2'd0
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

   //The tracking loop control memories hold
   //the control signals (Doppler, chipping rate,
   //and tau_prime) for a given channel.
   //FIXME Defines/ranges.
   wire [1:0]  control_addr_0;
   wire        control_wr_en_0;
   wire [52:0] control_in_0;
   wire [52:0] control_out_0;
   tracking_loop_ram (.DEPTH(2),
                      .ADDR_WIDTH(2),
                      .DATA_WIDTH(53))
     control_ram_0(.clock(clk),
                   .address_a(track_mem_addr_0),
                   .wren_a(track_mem_wr_en_0),
                   .data_a(track_mem_data_in_0),
                   .q_a(track_mem_data_out_0),
                   .address_b(control_addr_0),
                   .wren_b(control_wr_en_0),
                   .data_b(control_in_0),
                   .q_b(control_out_0));

   //The history memory holds the history values
   //for ALL channels and slots. It is addressed
   //by tracking tag ({channel,slot}).
   //FIXME Defines/ranges.
   wire [1:0]  hist_rd_addr;
   wire [1:0]  hist_wr_addr;
   wire        hist_wr_en;
   wire [52:0] hist_in;
   wire [52:0] hist_out;
   tracking_hist_ram (.ADDR_WIDTH(2),
                      .DATA_WIDTH(53))
     history_ram(.clock(clk),
                 .rdaddress(hist_rd_addr),
                 .data(hist_out),
                 .wraddress(hist_wr_addr),
                 .wren(hist_wr_en),
                 .q(hist_out));

   //Issue a read for the history values for the
   //tag that has completed sqrt.
   //Note: The M4K takes 2 cycles to read.
   assign hist_rd_addr = iq_tag;

   //Decode history results.
   //Note: i_prompt_k and q_prompt_k are stored
   //      above, and are only valid if the tracking
   //      updates are serialized.
   wire [`IQ_RANGE]        iq_prompt_km1;
   wire [`ACC_RANGE_TRACK] i_prompt_km1;
   wire [`ACC_RANGE_TRACK] q_prompt_km1;
   wire [`W_DF_RANGE]      w_df_k;
   wire [`W_DF_DOT_RANGE]  w_df_dot_k;
   
   //FIXME Read tracking history from M4K.

   //Delay start of tracking loops by two cycles
   //to allow history memory read to complete.
   wire start_loops;
   delay #(.DELAY(2))
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
   `KEEP wire                      fll_result_ready;
   `KEEP wire [`CHANNEL_ID_RANGE]  fll_result_tag;
   `KEEP wire [`DOPPLER_INC_RANGE] doppler_inc_kp1;
   `KEEP wire [`W_DF_RANGE]        w_df_kp1;
   `KEEP wire [`W_DF_DOT_RANGE]    w_df_dot_kp1;
   fll fll0(.clk(clk),
            .reset(reset),
            .start(loop_start_status[1]),
            .tag(`CHANNEL_ID_WIDTH'd0),
            .starting(fll_starting),
            .iq_prompt_k(iq_prompt_k),
            .iq_prompt_km1(iq_prompt_km1_0),
            .i_prompt_k(i_prompt_k),
            .q_prompt_k(q_prompt_k),
            .i_prompt_km1(i_prompt_km1_0),
            .q_prompt_km1(q_prompt_km1_0),
            .w_df_k(w_df_k_0),
            .w_df_dot_k(w_df_dot_k_0),
            .result_ready(fll_result_ready),
            .result_tag(fll_result_tag),
            .doppler_inc_kp1(doppler_inc_kp1),
            .w_df_kp1(w_df_kp1),
            .w_df_dot_kp1(w_df_dot_kp1));

   //Delay-locked loop.
   `KEEP wire                     dll_result_ready;
   `KEEP wire [`CHANNEL_ID_RANGE] dll_result_tag;
   `KEEP wire [`DLL_DPHI_RANGE]   dll_dphi_kp1;
   wire [`DLL_TAU_RANGE]          tau_prime_kp1;
   wire                           w_df_ready;
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
            .ca_dphi(dll_dphi_kp1),
            .tau_prime(tau_prime_kp1));

   //Sign-extend DLL phase increment to CA increment width.
   //FIXME Remove this and resize ca_dphi in DLL.
   wire [`CA_PHASE_INC_RANGE] ca_dphi_kp1;
   assign ca_dphi_kp1 = {{(`CA_PHASE_INC_WIDTH-`DLL_DPHI_WIDTH){dll_dphi_kp1[`DLL_DPHI_WIDTH-1]}},dll_dphi_kp1};

   ////////////////////
   // Report Results
   ////////////////////

   //FIXME Store results in M4K.

   //FIXME Assert tracking_update_complete to the top.

   //Store channel 0 results.
   //FIXME Update everything for multi-channel.
   `PRESERVE reg [1:0] channel_0_loop_status;
   always @(posedge clk) begin
      //Flag each loop's completion for one cycle.
      channel_0_loop_status <= reset ? 2'h0 :
                               tracking_ready_0 ? 2'h0 :
                               fll_result_ready ? channel_0_loop_status | 2'b10 :
                               dll_result_ready ? channel_0_loop_status | 2'b01 :
                               channel_0_loop_status;
      
      //Store prompt IQ value to return to channel history.
      iq_prompt_k_0 <= iq_values_ready ? iq_prompt_k_value : iq_prompt_k_0;
      
      //Flag tracking complete for one cycle
      //as soon as all tracking loops finish.
      tracking_ready_0 <= channel_0_loop_status==2'b11 && !tracking_ready_0;

      //FLL results.
      if(fll_result_ready) begin
         doppler_inc_kp1_0 <= doppler_inc_kp1;
         w_df_kp1_0 <= w_df_kp1;
         w_df_dot_kp1_0 <= w_df_dot_kp1;
      end

      //FLL results.
      if(dll_result_ready) begin
         ca_dphi_kp1_0 <= ca_dphi_kp1;
         tau_prime_kp1_0 <= tau_prime_kp1;
      end
   end // always @ (posedge clk)

   assign w_df_ready = channel_0_loop_status[1];
   assign w_df_kp1_to_dll = w_df_kp1_0;
   
endmodule