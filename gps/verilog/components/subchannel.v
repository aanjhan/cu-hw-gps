`include "global.vh"
`include "subchannel.vh"
`include "channel__subchannel.vh"
`include "cos.vh"
`include "sin.vh"

//`define DISABLE_CARRIER

module subchannel(
    input                      clk,
    input                      global_reset,
    input                      clear,
    //Sample data.
    input                      data_available,
    input                      feed_complete,
    input [`INPUT_RANGE]       data,
    //Carrier control.
    input [`DOPPLER_INC_RANGE] doppler,
    //Code control.
    input [4:0]                prn,
    input                      seek_en,
    input [`CS_RANGE]          seek_target,
    output wire                seeking,
    output wire [`CS_RANGE]    code_shift,
    //Outputs.
    output wire                accumulator_updating,
    output wire [`ACC_RANGE]   accumulator_i,
    output wire [`ACC_RANGE]   accumulator_q,
    output wire                accumulation_complete,
    //Debug outputs.
    output wire                ca_bit,
    output wire                ca_clk,
    output wire [9:0]          ca_code_shift);

   //Upsample the C/A code to the incoming sampling rate.
   ca_upsampler upsampler(.clk(clk),
                          .reset(global_reset),
                          .enable(data_available),
                          .prn(prn),
                          .code_shift(code_shift),
                          .out(ca_bit),
                          .seek_en(seek_en),
                          .seek_target(seek_target),
                          .seeking(seeking),
                          .ca_clk(ca_clk),
                          .ca_code_shift(ca_code_shift));

   //Delay accumulation 3 cycles to allow
   //for C/A upsampler to update. Delay 1
   //cycle to meet timing from the C/A bit
   //to the track accumulator.
   localparam DATA_DELAY = 4;
   (* keep *) wire data_available_kmnm1;
   delay #(.DELAY(DATA_DELAY-1))
     data_available_delay(.clk(clk),
                          .reset(global_reset),
                          .in(data_available),
                          .out(data_available_kmnm1));
   
   (* keep *) wire data_available_kmn;
   delay data_available_delay_2(.clk(clk),
                              .reset(global_reset),
                              .in(data_available_kmnm1),
                              .out(data_available_kmn));
     
   (* keep *) wire [`INPUT_RANGE] data_kmn;
   delay #(.WIDTH(`INPUT_WIDTH),
           .DELAY(DATA_DELAY))
     data_delay(.clk(clk),
                .reset(global_reset),
                .in(data),
                .out(data_kmn));
   
   (* keep *) wire ca_bit_kmn;
   delay ca_bit_delay(.clk(clk),
                      .reset(global_reset),
                      .in(ca_bit),
                      .out(ca_bit_kmn));

   //Delay feed complete signal for C/A upsampler
   //update length, plus post-mixing timing delay below,
   //plus two cycles for accumulator update.
   delay #(.DELAY(DATA_DELAY+3))
     feed_complete_delay(.clk(clk),
                         .reset(global_reset),
                         .in(feed_complete && data_available),
                         .out(accumulation_complete));

   //Carrier value is front-end intermediate frequency plus
   //sign-extended version of two's complement Doppler shift.
   wire [`CARRIER_PHASE_INC_RANGE] f_carrier;
   assign f_carrier = `F_IF_INC+{{`DOPPLER_PAD_SIZE{doppler[`DOPPLER_INC_WIDTH-1]}},doppler};

   //The carrier generator updates to the next carrier value
   //when a new data sample is available. The current value
   //to be used is the value one cycle BEFORE the update.
   wire [`CARRIER_LUT_INDEX_RANGE] carrier_index;
   dds #(.ACC_WIDTH(`CARRIER_ACC_WIDTH),
         .PHASE_INC_WIDTH(`CARRIER_PHASE_INC_WIDTH),
         .OUTPUT_WIDTH(`CARRIER_LUT_INDEX_WIDTH),
         .PIPELINE(1))
     carrier_generator(.clk(clk),
                       .reset(global_reset),
                       .enable(data_available_kmnm1),
                       .inc(f_carrier),//FIXME Two's complement for doppler value? How to represent/pad?
                       .out(carrier_index));

   //Generate in-phase carrier-wiped signal.
   (* keep *) wire [`CARRIER_LUT_RANGE] carrier_i;
`ifdef DISABLE_CARRIER
   assign carrier_i = `CARRIER_LUT_WIDTH'h1;
`else
   cos carrier_cos_lut(.in(carrier_index),
                       .out(carrier_i));
`endif
   
   (* keep *) wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_i;
   mult carrier_mux_i(.carrier(carrier_i),
                      .signal(data_kmn),
                      .out(sig_no_carrier_i));

   //Generate quadrature carrier-wiped signal.
   (* keep *) wire [`CARRIER_LUT_RANGE] carrier_q;
`ifdef DISABLE_CARRIER
   assign carrier_q = `CARRIER_LUT_WIDTH'h0;
`else
   sin carrier_sin_lut(.in(carrier_index),
                       .out(carrier_q));
`endif
   
   (* keep *) wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_q;
   mult carrier_mux_q(.carrier(carrier_q),
                      .signal(data_kmn),
                      .out(sig_no_carrier_q));

   //Pipe post-carrier wipe signals to meet timing.
   wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_i_km1;
   delay #(.WIDTH(`SIG_NO_CARRIER_WIDTH))
     post_carrier_i_delay(.clk(clk),
                          .reset(global_reset),
                          .in(sig_no_carrier_i),
                          .out(sig_no_carrier_i_km1));
   
   wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_q_km1;
   delay #(.WIDTH(`SIG_NO_CARRIER_WIDTH))
     post_carrier_q_delay(.clk(clk),
                          .reset(global_reset),
                          .in(sig_no_carrier_q),
                          .out(sig_no_carrier_q_km1));

   wire track_ca_bit;
   delay post_carrier_ca_delay(.clk(clk),
                               .reset(global_reset),
                               .in(ca_bit_kmn),
                               .out(track_ca_bit));

   wire track_data_available;
   delay post_carrier_available_delay(.clk(clk),
                                      .reset(global_reset),
                                      .in(data_available_kmn),
                                      .out(track_data_available));

   //Track takes 2 cycles to update.
   delay acc_updating_delay(.clk(clk),
                            .reset(global_reset),
                            .in(track_data_available),
                            .out(accumulator_updating));
   
   //In-phase code wipe-off and accumulation.
   track #(.INPUT_WIDTH(`SIG_NO_CARRIER_WIDTH),
           .OUTPUT_WIDTH(`ACC_WIDTH))
     track_i(.clk(clk),
             .reset(global_reset || clear),
             .data_available(track_data_available),
             .baseband_input(sig_no_carrier_i_km1),
             .ca_bit(track_ca_bit),
             .accumulator(accumulator_i));
   
   track #(.INPUT_WIDTH(`SIG_NO_CARRIER_WIDTH),
           .OUTPUT_WIDTH(`ACC_WIDTH))
     track_q(.clk(clk),
             .reset(global_reset || clear),
             .data_available(track_data_available),
             .baseband_input(sig_no_carrier_q_km1),
             .ca_bit(track_ca_bit),
             .accumulator(accumulator_q));
endmodule