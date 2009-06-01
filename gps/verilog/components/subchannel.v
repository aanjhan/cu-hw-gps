`include "global.vh"
`include "subchannel.vh"
`include "cos.vh"
`include "sin.vh"

module subchannel(
    input                      clk,
    input                      global_reset,
    input                      reset,
    //Sample data.
    input                      data_available,
    input [`INPUT_RANGE]       data,
    //Carrier control.
    input [`DOPPLER_INC_RANGE] doppler,
    //Code control.
    input [4:0]                prn,
    input                      seek_en,
    input [`CS_RANGE]          seek_target,
    output wire [`CS_RANGE]    code_shift,
    //Outputs.
    output wire [`ACC_RANGE]   accumulator_i,
    output wire [`ACC_RANGE]   accumulator_q,
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
                          .ca_clk(ca_clk),
                          .ca_code_shift(ca_code_shift));

   //Delay accumulation 4 cycles to allow
   //for C/A upsampler to update. Delay 1
   //cycle to meet timing from the C/A bit
   //to the track accumulator.
   localparam DATA_DELAY = 5;
   wire data_available_kmn /* synthesis keep */;
   delay #(.DELAY(DATA_DELAY))
     data_available_delay(.clk(clk),
                          .reset(reset),
                          .in(data_available),
                          .out(data_available_kmn));
     
   wire [`INPUT_RANGE] data_kmn /* synthesis keep */;
   delay #(.WIDTH(`INPUT_WIDTH),
           .DELAY(DATA_DELAY))
     data_delay(.clk(clk),
                .reset(reset),
                .in(data),
                .out(data_kmn));
   
   wire ca_bit_kmn /* synthesis keep */;
   delay ca_bit_delay(.clk(clk),
                      .reset(reset),
                      .in(ca_bit),
                      .out(ca_bit_kmn));

   wire [`CARRIER_PHASE_INC_RANGE] f_carrier;
   assign f_carrier = `F_IF_INC+{{`DOPPLER_PAD_SIZE{1'b0}},doppler};
   
   wire [`CARRIER_LUT_RANGE] carrier_index;
   dds2 #(.ACC_WIDTH(`CARRIER_ACC_WIDTH),
          .PHASE_INC_WIDTH(`CARRIER_PHASE_INC_WIDTH),
          .OUTPUT_WIDTH(`CARRIER_LUT_WIDTH))
         carrier_generator(.clk(clk),
                           .reset(global_reset),
                           .enable(1'b1),
                           .inc(f_carrier),//FIXME Two's complement for doppler value? How to represent/pad?
                           .out(carrier_index));

   //Generate in-phase carrier-wiped signal.
   wire [`COS_OUTPUT_RANGE] carrier_i;
   /*cos carrier_cos_lut(.in(carrier_index),
                       .out(carrier_i));*/
   assign carrier_i = `COS_OUTPUT_WIDTH'h1;
   
   wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_i;
   mult carrier_mux_i(.carrier(carrier_i),
                      .signal(data_kmn),
                      .out(sig_no_carrier_i));

   //Generate quadrature carrier-wiped signal.
   wire [`COS_OUTPUT_RANGE] carrier_q;
   sin carrier_sin_lut(.in(carrier_index),
                       .out(carrier_q));
   
   wire [`SIG_NO_CARRIER_RANGE] sig_no_carrier_q;
   mult carrier_mux_q(.carrier(carrier_q),
                      .signal(data_kmn),
                      .out(sig_no_carrier_q));
   
   //In-phase code wipe-off and accumulation.
   track #(.INPUT_WIDTH(`SIG_NO_CARRIER_WIDTH),
           .OUTPUT_WIDTH(`ACC_WIDTH))
     track_i(.clk(clk),
             .reset(reset),
             .data_available(data_available_kmn),
             .baseband_input(sig_no_carrier_i),
             .ca_bit(ca_bit_kmn),
             .accumulator(accumulator_i));
   
   track #(.INPUT_WIDTH(`SIG_NO_CARRIER_WIDTH),
           .OUTPUT_WIDTH(`ACC_WIDTH))
     track_q(.clk(clk),
             .reset(reset),
             .data_available(data_available_kmn),
             .baseband_input(sig_no_carrier_q),
             .ca_bit(ca_bit_kmn),
             .accumulator(accumulator_q));
endmodule