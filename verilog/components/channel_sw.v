`include "global.vh"
`include "channel.vh"
`include "channel__ca_upsampler.vh"
`include "channel__tracking_loops.vh"
//`include "top__channel.vh"

`include "subchannel.vh"
`include "ca_upsampler.vh"

`define DEBUG
`include "debug.vh"

module channel_sw(
    input                    clk,
    input                    reset,
    //Real-time sample interface.
    input                    data_available,
    input [`INPUT_RANGE]     data,
    //Slot initialization.
    input                       init_ready,
    input [`PRN_RANGE]          init_prn,
    input [`DOPPLER_INC_RANGE]  init_carrier_dphi,
    input [`CS_RANGE]           init_code_shift,
    input [`CA_ACC_RANGE]       init_ca_clk_acc,
    input                       init_ca_clk_hist,
    input [`CA_CHIP_HIST_RANGE] init_prompt_chip_hist,
    input [`CA_CHIP_HIST_RANGE] init_late_chip_hist,
    input [10:1]                init_g1,
    input [10:1]                init_g2,
    output wire                 slot_initializing,
    //Tracking loop initialization.
    output wire              init_track,
    output wire [1:0]        init_track_tag,
    output wire [`DOPPLER_INC_RANGE] init_track_carrier_dphi,
    //Accumulation results.
    //FIXME Switch accumulators to ACC_RANGE_TRACK
    output wire              acc_valid,
    output wire [1:0]        acc_tag,
    output wire [`ACC_RANGE] i_early,
    output wire [`ACC_RANGE] q_early,
    output wire [`ACC_RANGE] i_prompt,
    output wire [`ACC_RANGE] q_prompt,
    output wire [`ACC_RANGE] i_late,
    output wire [`ACC_RANGE] q_late,
    //Tracking result memory interface.
    //FIXME Bit ranges.
    input [1:0]              track_mem_addr,
    input                    track_mem_wr_en,
    input [52:0]             track_mem_data);
   
   //Cycle through PRN slots in channel.
   //The slot number indicates which slot
   //is in pipeline stage 0.
   //FIXME Add defines for this somewhere.
   localparam NUM_SLOTS = 1;
   localparam [1:0] MAX_SLOT = NUM_SLOTS-1;
   reg [1:0] slot;
   reg       active;
   always @(posedge clk) begin
      slot <= reset ? 2'd0 :
              !active ? slot :
              slot==MAX_SLOT ? 2'd0 :
              slot+2'd1;

      active <= reset ? 1'b0 :
                data_available ? 1'b1 :
                slot==MAX_SLOT ? 1'b0 :
                active;
   end // always @ (posedge clk)

   //Select next available slot.
   reg [(NUM_SLOTS-1):0] slot_active;
   `KEEP wire [1:0] next_slot;
   `KEEP wire [(NUM_SLOTS-1):0] next_slot_oh;
   priority_select #(.NUM_ENTRIES(NUM_SLOTS))
     slot_select(.eligible(~slot_active),
                 .select(next_slot),
                 .select_oh(next_slot_oh));

   //Start next-available slot when initialization
   //requested from top level.
   reg [`PRN_RANGE] slot_prn[(NUM_SLOTS-1):0];
   genvar i;
   generate
      for(i=0;i<NUM_SLOTS;i=i+1) begin : slot_status_gen
         always @(posedge clk) begin
            slot_active[i] <= reset ? 1'b0 :
                              slot_initializing && next_slot_oh[i] ? 1'b1 :
                              slot_active[i];

            slot_prn[i] <= reset ? `PRN_WIDTH'd0 :
                           slot_initializing && next_slot_oh[i] ? init_prn :
                           slot_prn[i];
         end
      end
   endgenerate

   //////////////////////////////
   // Channel Slot State Memory
   //////////////////////////////

   //Note: The channel slot memories are flopped
   //      on both the inputs and outputs. This
   //      means that the results are not available
   //      for 2 cycles after doing a read.
   
   //Slot state memory.
   //FIXME Add define for this.
   `KEEP wire         slot_mem_wr_en;
   `KEEP wire [1:0]   slot_mem_wr_addr;
   `KEEP wire [110:0] slot_mem_in;
   `KEEP wire [1:0]   slot_mem_rd_addr;
   `KEEP wire [110:0] slot_mem_out;
   channel_slot_mem #(.DEPTH(2),
                      .ADDR_WIDTH(2),
                      .DATA_WIDTH(111))
     slot_mem(.clock(clk),
              .aclr(reset),
	      .wren(slot_mem_wr_en),
	      .wraddress(slot_mem_wr_addr),
	      .data(slot_mem_in),
	      .rdaddress(slot_mem_rd_addr),
	      .q(slot_mem_out));
   
   //Accumulator state memory.
   //FIXME Add define for this.
   `KEEP wire         acc_mem_wr_en;
   `KEEP wire [1:0]   acc_mem_wr_addr;
   `KEEP wire [119:0] acc_mem_in;
   `KEEP wire [1:0]   acc_mem_rd_addr;
   `KEEP wire [119:0] acc_mem_out;
   channel_slot_mem #(.DEPTH(2),
                      .ADDR_WIDTH(2),
                      .DATA_WIDTH(6*`ACC_WIDTH))//FIXME
     acc_mem(.clock(clk),
             .aclr(reset),
	     .wren(acc_mem_wr_en),
	     .wraddress(acc_mem_wr_addr),
	     .data(acc_mem_in),
	     .rdaddress(acc_mem_rd_addr),
	     .q(acc_mem_out));

   //The tracking loop control memories hold
   //the control signals (Doppler, chipping rate,
   //and tau_prime) for a given channel.
   //FIXME Defines/ranges.
   `KEEP wire [1:0]  control_addr;
   `KEEP wire        control_wr_en;
   `KEEP wire [52:0] control_data_in;
   `KEEP wire [52:0] control_data_out;
   wire [52:0] control_track_data_out;
   tracking_loop_ram #(.DEPTH(2),
                       .ADDR_WIDTH(2),
                       .DATA_WIDTH(53))
     control_ram(.clock(clk),
                 .address_a(track_mem_addr),
                 .wren_a(track_mem_wr_en),
                 .data_a(track_mem_data),
                 .q_a(control_track_data_out),
                 .address_b(control_addr),
                 .wren_b(control_wr_en),
                 .data_b(control_data_in),
                 .q_b(control_data_out));

   ///////////////////////////////////
   // Pipeline Stage 0:
   //   --Fetch slot state.
   //   --Fetch slot tracking results.
   ///////////////////////////////////

   //Fetch current slot's state.
   assign slot_mem_rd_addr = slot;
   
   `KEEP wire [1:0] slot_km1;
   delay #(.WIDTH(2))
     slot_delay_0(.clk(clk),
                  .reset(reset),
                  .in(slot),
                  .out(slot_km1));

   `KEEP wire active_km1;
   delay active_delay_0(.clk(clk),
                        .reset(reset),
                        .in(active && slot_active[slot]),
                        .out(active_km1));

   `KEEP wire [`INPUT_RANGE] data_km1;
   delay #(.WIDTH(`INPUT_WIDTH))
     data_delay_0(.clk(clk),
                  .reset(reset),
                  .in(data),
                  .out(data_km1));

   ///////////////////////////////////
   // Pipeline Stage 1:
   //   --Wait for slot state.
   //   --Wait for tracking results.
   ///////////////////////////////////
   
   `KEEP wire [1:0] slot_km2;
   delay #(.WIDTH(2))
     slot_delay_1(.clk(clk),
                  .reset(reset),
                  .in(slot_km1),
                  .out(slot_km2));

   `KEEP wire active_km2;
   delay active_delay_1(.clk(clk),
                        .reset(reset),
                        .in(active_km1),
                        .out(active_km2));

   `KEEP wire [`INPUT_RANGE] data_km2;
   delay #(.WIDTH(`INPUT_WIDTH))
     data_delay_1(.clk(clk),
                  .reset(reset),
                  .in(data_km1),
                  .out(data_km2));

   //////////////////////////////
   // Pipeline Stage 2:
   //   --Update carrier DDS.
   //   --Update code DDS.
   //////////////////////////////

   //Decode state memory output.
   //FIXME Make defines for these.
   //FIXME Get init values from startup C/A upsampler.
   `KEEP wire [`CARRIER_ACC_RANGE]  carrier_acc_in;
   `KEEP wire [`CS_RANGE]           code_shift_in;
   `KEEP wire [`CA_ACC_RANGE]       ca_clk_acc_in;
   `KEEP wire                       ca_clk_hist_in;
   `KEEP wire [`CA_CHIP_HIST_RANGE] prompt_chip_hist_in;
   `KEEP wire [`CA_CHIP_HIST_RANGE] late_chip_hist_in;
   `KEEP wire [10:1]                g1_in;
   `KEEP wire [10:1]                g2_in;
   `KEEP wire [`SAMPLE_COUNT_TRACK_RANGE] sample_count_in;
   assign sample_count_in = slot_mem_out[110:96];
   assign g1_in = slot_mem_out[95:86];
   assign g2_in = slot_mem_out[85:76];
   assign carrier_acc_in = slot_mem_out[75:49];
   assign code_shift_in = slot_mem_out[48:34];
   assign ca_clk_acc_in = slot_mem_out[33:9];
   assign ca_clk_hist_in = slot_mem_out[8];
   assign prompt_chip_hist_in = slot_mem_out[7:4];
   assign late_chip_hist_in = slot_mem_out[3:0];
   
   //Fetch tracking control results from memory.
   //FIXME Ranges.
   `KEEP wire [`SAMPLE_COUNT_TRACK_RANGE] tau_prime;
   `KEEP wire [`DOPPLER_INC_RANGE] doppler_dphi;
   `KEEP wire [`CA_PHASE_INC_RANGE] ca_dphi;
   assign tau_prime = control_data_out[52:38];
   assign ca_dphi = control_data_out[37:17];
   assign doppler_dphi = control_data_out[16:0];

   //Flag accumulation completion when enough
   //samples have been accumulated.
   `KEEP wire accumulation_complete;
   assign accumulation_complete = sample_count_in==(`SAMPLE_COUNT_TRACK_MAX-`SAMPLE_COUNT_TRACK_WIDTH'd1);
   
   `KEEP wire [`SAMPLE_COUNT_TRACK_RANGE] sample_count_out;
   assign sample_count_out = accumulation_complete ? `SAMPLE_COUNT_TRACK_WIDTH'd0 :
                             sample_count_in+`SAMPLE_COUNT_TRACK_WIDTH'd1;

   //Clear the accumulators on the first sample.
   wire clear;
   assign clear = sample_count_in==`SAMPLE_COUNT_TRACK_WIDTH'd0;

   //Carrier value is front-end intermediate frequency plus
   //sign-extended version of two's complement Doppler shift.
   wire [`CARRIER_PHASE_INC_RANGE] f_carrier;
   assign f_carrier = `MIXING_SIGN ?
                      `F_IF_INC-{{`DOPPLER_PAD_SIZE{doppler_dphi[`DOPPLER_INC_WIDTH-1]}},doppler_dphi} :
                      `F_IF_INC+{{`DOPPLER_PAD_SIZE{doppler_dphi[`DOPPLER_INC_WIDTH-1]}},doppler_dphi};

   //Generate the carrier frequency.
   //Note: This DDS module is internally pipelined
   //      by 1 cycle. The result is ready in stage 3.
   wire [`CARRIER_LUT_INDEX_RANGE] carrier_index_km3;
   wire [`CARRIER_ACC_RANGE]       carrier_acc_out_km3;
   dds_sw #(.ACC_WIDTH(`CARRIER_ACC_WIDTH),
            .PHASE_INC_WIDTH(`CARRIER_PHASE_INC_WIDTH),
            .OUTPUT_WIDTH(`CARRIER_LUT_INDEX_WIDTH),
            .PIPELINE(1))
     carrier_generator(.clk(clk),
                       .reset(reset),
                       .enable(active_km2),
                       .acc_in(carrier_acc_in),
                       .acc_out(carrier_acc_out_km3),
                       .inc(f_carrier),
                       .out(carrier_index_km3));

   //Generate the upsampled C/A code.
   //Note: The C/A upsampler is internally pipelined.
   //      The C/A bits are ready in stage 3.
   `KEEP wire ca_bit_early_km3, ca_bit_prompt_km3, ca_bit_late_km3;
   `KEEP wire [`CS_RANGE]           code_shift_out;
   `KEEP wire [`CA_ACC_RANGE]       ca_clk_acc_out;
   `KEEP wire                       ca_clk_hist_out;
   `KEEP wire [`CA_CHIP_HIST_RANGE] prompt_chip_hist_out_km3;
   `KEEP wire [`CA_CHIP_HIST_RANGE] late_chip_hist_out_km3;
   `KEEP wire [10:1]                g1_out_km3;
   `KEEP wire [10:1]                g2_out_km3;
   ca_upsampler_sw upsampler(.clk(clk),
                             .reset(reset),
                             //Control interface.
                             .prn(slot_prn[slot_km2]),
                             .ca_dphi(ca_dphi),
                             //C/A code output interface.
                             .out_early(ca_bit_early_km3),
                             .out_prompt(ca_bit_prompt_km3),
                             .out_late(ca_bit_late_km3),
                             //C/A upsampler state.
                             .code_shift_in(code_shift_in),
                             .ca_clk_acc_in(ca_clk_acc_in),
                             .ca_clk_hist_in(ca_clk_hist_in),
                             .prompt_chip_hist_in(prompt_chip_hist_in),
                             .late_chip_hist_in(late_chip_hist_in),
                             .code_shift_out(code_shift_out),
                             .ca_clk_acc_out(ca_clk_acc_out),
                             .ca_clk_hist_out(ca_clk_hist_out),
                             .prompt_chip_hist_out(prompt_chip_hist_out_km3),
                             .late_chip_hist_out(late_chip_hist_out_km3),
                             //C/A generator state.
                             .g1_in(g1_in),
                             .g2_in(g2_in),
                             .g1_out(g1_out_km3),
                             .g2_out(g2_out_km3));

   //Pipe C/A upsampler state to next stage.
   `KEEP wire [1:0] slot_km3;
   delay #(.WIDTH(2))
     slot_delay_2(.clk(clk),
                  .reset(reset),
                  .in(slot_km2),
                  .out(slot_km3));
   
   `KEEP wire active_km3;
   delay active_delay_2(.clk(clk),
                        .reset(reset),
                        .in(active_km2),
                        .out(active_km3));
   
   wire [`CS_RANGE] code_shift_out_km3;
   delay #(.WIDTH(`CS_WIDTH))
     code_shift_delay(.clk(clk),
                      .reset(reset),
                      .in(code_shift_out),
                      .out(code_shift_out_km3));
   
   wire [`CA_ACC_RANGE] ca_clk_acc_out_km3;
   delay #(.WIDTH(`CA_ACC_WIDTH))
     ca_clk_acc_delay(.clk(clk),
                      .reset(reset),
                      .in(ca_clk_acc_out),
                      .out(ca_clk_acc_out_km3));
   
   wire ca_clk_hist_out_km3;
   delay ca_clk_hist_delay(.clk(clk),
                           .reset(reset),
                           .in(ca_clk_hist_out),
                           .out(ca_clk_hist_out_km3));
   
   wire [`SAMPLE_COUNT_TRACK_RANGE] sample_count_out_km3;
   delay #(.WIDTH(`SAMPLE_COUNT_TRACK_WIDTH))
     sample_count_delay(.clk(clk),
                        .reset(reset),
                        .in(sample_count_out),
                        .out(sample_count_out_km3));

   //Delay data until next stage.
   `KEEP wire [`INPUT_RANGE] data_km3;
   delay #(.WIDTH(`INPUT_WIDTH))
     data_delay(.clk(clk),
                .reset(reset),
                .in(data_km2),
                .out(data_km3));

   `KEEP wire acc_complete_km3;
   delay acc_complete_delay_2(.clk(clk),
                              .reset(reset),
                              .in(accumulation_complete),
                              .out(acc_complete_km3));

   ///////////////////////////////////
   // Pipeline Stage 3:
   //   --Update slot state.
   //   --Generate carrier signals.
   //   --Wipe-off carrier.
   ///////////////////////////////////

   //Initialize tracking control memory whenever an
   //initialization is pending and the channel is idle.
   assign control_addr = next_slot;
   assign control_wr_en = !active_km3 && init_ready && |next_slot_oh;

   //FIXME Get rid of tau_prime (unneeded).
   //FIXME Ranges.
   assign control_data_in[52:38] = `SAMPLE_COUNT_TRACK_WIDTH'd0;
   assign control_data_in[37:17] = 21'd0;
   assign control_data_in[16:0] = init_carrier_dphi;

   assign init_track = control_wr_en;
   assign init_track_tag = control_addr;
   assign init_track_carrier_dphi = init_carrier_dphi;

   //Assert flag to top level to clear initializaiton request.
   assign slot_initializing = control_wr_en;

   //Write slot state to memory.
   assign slot_mem_in[110:96] = slot_initializing ? 15'd0 : sample_count_out_km3;
   assign slot_mem_in[95:86] = slot_initializing ? init_g1 : g1_out_km3;
   assign slot_mem_in[85:76] = slot_initializing ? init_g2 : g2_out_km3;
   assign slot_mem_in[75:49] = slot_initializing ? `CARRIER_ACC_WIDTH'd0 : carrier_acc_out_km3;
   assign slot_mem_in[48:34] = slot_initializing ? init_code_shift : code_shift_out_km3;
   assign slot_mem_in[33:9] = slot_initializing ? init_ca_clk_acc : ca_clk_acc_out_km3;
   assign slot_mem_in[8] = slot_initializing ? init_ca_clk_hist : ca_clk_hist_out_km3;
   assign slot_mem_in[7:4] = slot_initializing ? init_prompt_chip_hist : prompt_chip_hist_out_km3;
   assign slot_mem_in[3:0] = slot_initializing ? init_late_chip_hist : late_chip_hist_out_km3;

   assign slot_mem_wr_en = slot_initializing || active_km3;
   assign slot_mem_wr_addr = slot_initializing ? next_slot : slot_km3;

   //Generate in-phase (cos) and quadrature (sin)
   //carrier signals.
   `KEEP wire [`CARRIER_LUT_RANGE] carrier_i;
   cos carrier_cos_lut(.in(carrier_index_km3),
                       .out(carrier_i));
   
   `KEEP wire [`CARRIER_LUT_RANGE] carrier_q;
   sin carrier_sin_lut(.in(carrier_index_km3),
                       .out(carrier_q));

   //Wipe off carrier in-phase and quadrature
   //carriers.
   `KEEP wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_i;
   mult carrier_mux_i(.carrier(carrier_i),
                      .signal(data_km3),
                      .out(sig_no_carrier_i));
   
   `KEEP wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_q;
   mult carrier_mux_q(.carrier({`MIXING_SIGN^carrier_q[`CARRIER_LUT_WIDTH-1],carrier_q[(`CARRIER_LUT_WIDTH-2):0]}),
                      .signal(data_km3),
                      .out(sig_no_carrier_q));

   //Pipe post-carrier wipe signals to stage 4.
   `KEEP wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_i_km4;
   delay #(.WIDTH(`SIG_NO_CARRIER_WIDTH))
     post_carrier_i_delay(.clk(clk),
                          .reset(reset),
                          .in(sig_no_carrier_i),
                          .out(sig_no_carrier_i_km4));
   
   `KEEP wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_q_km4;
   delay #(.WIDTH(`SIG_NO_CARRIER_WIDTH))
     post_carrier_q_delay(.clk(clk),
                          .reset(reset),
                          .in(sig_no_carrier_q),
                          .out(sig_no_carrier_q_km4));

   //Pipe code bits to stage 4.
   wire ca_bit_early_km4, ca_bit_prompt_km4, ca_bit_late_km4;
   delay #(.WIDTH(3))
     post_carrier_code_delay(.clk(clk),
                             .reset(reset),
                             .in({ca_bit_early_km3,ca_bit_prompt_km3,ca_bit_late_km3}),
                             .out({ca_bit_early_km4,ca_bit_prompt_km4,ca_bit_late_km4}));

   //Pipe slot control to next stage.
   `KEEP wire [1:0] slot_km4;
   delay #(.WIDTH(2))
     slot_delay_3(.clk(clk),
                  .reset(reset),
                  .in(slot_km3),
                  .out(slot_km4));
   
   `KEEP wire active_km4;
   delay active_delay_3(.clk(clk),
                        .reset(reset),
                        .in(active_km3),
                        .out(active_km4));

   //Pipe clear signal from stage 0 to stage 4.
   wire clear_km4;
   delay #(.DELAY(4))
     clear_delay(.clk(clk),
                 .reset(reset),
                 .in(clear || slot_initializing),
                 .out(clear_km4));

   `KEEP wire acc_complete_km4;
   delay acc_complete_delay_3(.clk(clk),
                              .reset(reset),
                              .in(acc_complete_km3),
                              .out(acc_complete_km4));

   /////////////////////////////////////////////
   // Pipeline Stage 4:
   //   --Wipe-off code.
   //   --Accumulate result.
   //   --Take I/Q absolute values.
   /////////////////////////////////////////////

   //Decode accumulator memory output.
   //FIXME Make defines for these.
   `KEEP wire [`ACC_RANGE] acc_i_early_in;
   `KEEP wire [`ACC_RANGE] acc_q_early_in;
   `KEEP wire [`ACC_RANGE] acc_i_prompt_in;
   `KEEP wire [`ACC_RANGE] acc_q_prompt_in;
   `KEEP wire [`ACC_RANGE] acc_i_late_in;
   `KEEP wire [`ACC_RANGE] acc_q_late_in;
   assign acc_i_early_in = acc_mem_out[119:100];
   assign acc_q_early_in = acc_mem_out[99:80];
   assign acc_i_prompt_in = acc_mem_out[79:60];
   assign acc_q_prompt_in = acc_mem_out[59:40];
   assign acc_i_late_in = acc_mem_out[39:20];
   assign acc_q_late_in = acc_mem_out[19:0];
   
   //Note: The subchannels are internally pipelined.
   //      The results are ready in stage 5.

   //Early subchannel.
   `KEEP wire [`ACC_RANGE] acc_i_early_out_km5;
   `KEEP wire [`ACC_RANGE] acc_q_early_out_km5;
   subchannel_sw #(.INPUT_WIDTH(`SIG_NO_CARRIER_WIDTH),
                   .OUTPUT_WIDTH(`ACC_WIDTH))
     subchannel_early(.clk(clk),
                      .reset(reset),
                      .clear(clear_km4),
                      .ca_bit(ca_bit_early_km4),
                      .data_i(sig_no_carrier_i_km4),
                      .data_q(sig_no_carrier_q_km4),
                      .accumulator_i_in(acc_i_early_in),
                      .accumulator_q_in(acc_q_early_in),
                      .accumulator_i_out(acc_i_early_out_km5),
                      .accumulator_q_out(acc_q_early_out_km5));

   //Prompt subchannel.
   `KEEP wire [`ACC_RANGE] acc_i_prompt_out_km5;
   `KEEP wire [`ACC_RANGE] acc_q_prompt_out_km5;
   subchannel_sw #(.INPUT_WIDTH(`SIG_NO_CARRIER_WIDTH),
                   .OUTPUT_WIDTH(`ACC_WIDTH))
     subchannel_prompt(.clk(clk),
                       .reset(reset),
                       .clear(clear_km4),
                       .ca_bit(ca_bit_prompt_km4),
                       .data_i(sig_no_carrier_i_km4),
                       .data_q(sig_no_carrier_q_km4),
                       .accumulator_i_in(acc_i_prompt_in),
                       .accumulator_q_in(acc_q_prompt_in),
                       .accumulator_i_out(acc_i_prompt_out_km5),
                       .accumulator_q_out(acc_q_prompt_out_km5));

   //Late subchannel.
   `KEEP wire [`ACC_RANGE] acc_i_late_out_km5;
   `KEEP wire [`ACC_RANGE] acc_q_late_out_km5;
   subchannel_sw #(.INPUT_WIDTH(`SIG_NO_CARRIER_WIDTH),
                   .OUTPUT_WIDTH(`ACC_WIDTH))
     subchannel_late(.clk(clk),
                     .reset(reset),
                     .clear(clear_km4),
                     .ca_bit(ca_bit_late_km4),
                     .data_i(sig_no_carrier_i_km4),
                     .data_q(sig_no_carrier_q_km4),
                     .accumulator_i_in(acc_i_late_in),
                     .accumulator_q_in(acc_q_late_in),
                     .accumulator_i_out(acc_i_late_out_km5),
                     .accumulator_q_out(acc_q_late_out_km5));

   //Pipe slot control to next stage.
   `KEEP wire [1:0] slot_km5;
   delay #(.WIDTH(2))
     slot_delay_4(.clk(clk),
                  .reset(reset),
                  .in(slot_km4),
                  .out(slot_km5));
   
   `KEEP wire active_km5;
   delay active_delay_4(.clk(clk),
                        .reset(reset),
                        .in(active_km4),
                        .out(active_km5));

   `KEEP wire acc_complete_km5;
   delay acc_complete_delay_4(.clk(clk),
                              .reset(reset),
                              .in(acc_complete_km4),
                              .out(acc_complete_km5));

   /////////////////////////////////////////////
   // Pipeline Stage 5:
   //   --Write back to accumulator memory.
   //   --Flag accumulation valid.
   /////////////////////////////////////////////

   //Write accumulator state to memory.
   assign acc_mem_in[119:100] = acc_i_early_out_km5;
   assign acc_mem_in[99:80] = acc_q_early_out_km5;
   assign acc_mem_in[79:60] = acc_i_prompt_out_km5;
   assign acc_mem_in[59:40] = acc_q_prompt_out_km5;
   assign acc_mem_in[39:20] = acc_i_late_out_km5;
   assign acc_mem_in[19:0] = acc_q_late_out_km5;

   assign acc_mem_wr_en = active_km5;
   assign acc_mem_wr_addr = slot_km5;

   //Output accumulation results to tracking loops.
   assign i_early = acc_i_early_out_km5;
   assign q_early = acc_q_early_out_km5;
   assign i_prompt = acc_i_prompt_out_km5;
   assign q_prompt = acc_q_prompt_out_km5;
   assign i_late = acc_i_late_out_km5;
   assign q_late = acc_q_late_out_km5;
   
   //Assert accumulation valid to tracking loops
   //at the end of an accumulation period.
   assign acc_valid = acc_complete_km5 && active_km5;

   //FIXME Pipe PRN to acc_tag.
   assign acc_tag = slot_km5;
   
endmodule