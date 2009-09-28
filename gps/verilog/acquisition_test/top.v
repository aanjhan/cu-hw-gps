`include "../components/global.vh"
`include "top__channel.vh"
`include "top__mem_bank.vh"

`define DEBUG
`include "../components/debug.vh"

`define HIGH_SPEED

module top(
    input                      clk,
    input                      global_reset,
    input [`MODE_RANGE]        mode,
    //Sample data.
    input                      clk_sample,
    input                      feed_reset,
    input                      feed_complete,
    input [`INPUT_RANGE]       data,
    //Carrier control.
    input [`DOPPLER_INC_RANGE] doppler,//FIXME range?
    //Code control.
    input [4:0]                prn,
    input                      seek_en,
    input [`CS_RANGE]          seek_target,
    output wire [`CS_RANGE]    code_shift,
    //Outputs.
    output wire [`ACC_RANGE]   accumulator_i,
    output wire [`ACC_RANGE]   accumulator_q,
    output wire                i2q2_valid,
    output wire [`I2Q2_RANGE]  i2q2_early,
    output wire [`I2Q2_RANGE]  i2q2_prompt,
    output wire [`I2Q2_RANGE]  i2q2_late,
    //Acquisition results.
    output wire                      acquisition_complete,
    output wire [`I2Q2_RANGE]        acq_peak_i2q2,
    output wire [`DOPPLER_INC_RANGE] acq_peak_doppler,
    output wire [`CS_RANGE]          acq_peak_code_shift,
    //Debug signals.
    output wire                ca_bit,
    output wire                ca_clk,
    output wire [9:0]          ca_code_shift);

   //Clock domain crossing.
   `KEEP wire clk_sample_sync;
   synchronizer input_clk_sync(.clk(clk),
                               .in(clk_sample),
                               .out(clk_sample_sync));
   
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
   `KEEP wire data_available;
`ifndef HIGH_SPEED
   strobe data_available_strobe(.clk(clk),
                                .reset(global_reset),
                                .in(clk_sample_sync),
                                .out(data_available));
`else
   reg data_active;
   always @(posedge clk) begin
      data_active <= global_reset ? 1'b0 :
                     feed_reset_sync ? 1'b1 :
                     feed_complete_sync ? 1'b0 :
                     data_active;
   end
   assign data_available = !global_reset &&
                           (feed_reset_sync || data_active);
`endif // !`ifndef HIGH_SPEED

   `PRESERVE reg mem_mode;
   always @(posedge clk) begin
      mem_mode <= global_reset ? `MODE_WRITING :
                  data_available && feed_complete_sync ? `MODE_PLAYBACK :
                  mem_mode;
   end

   //Memory bank.
   `KEEP wire mem_bank_ready;
   `KEEP wire mem_bank_frame_start;
   `KEEP wire mem_bank_frame_end;
   `KEEP wire mem_bank_sample_valid;
   `KEEP wire [`INPUT_RANGE] mem_bank_data;
   mem_bank bank_0(.clk(clk),
                   .reset(global_reset),
                   .mode(mem_mode),//FIXME
                   .data_available(data_available),
                   .data_in(data_sync),
                   .ready(mem_bank_ready),
                   .frame_start(mem_bank_frame_start),
                   .frame_end(mem_bank_frame_end),
                   .sample_valid(mem_bank_sample_valid),
                   .data_out(mem_bank_data));

   //Channel.
   wire accumulator_updating;
   channel channel_0(.clk(clk),
                     .global_reset(global_reset),
                     .mode(mode),
                     .feed_reset(mem_bank_frame_start),
                     .data_available(mem_bank_sample_valid),
                     .feed_complete(mem_bank_frame_end),
                     .data(mem_bank_data),
                     .doppler_early(doppler+`DOPP_BIN_INC),
                     .doppler_prompt(doppler),
                     .doppler_late(doppler-`DOPP_BIN_INC),
                     .prn(prn),
                     .seek_en(seek_en),
                     .seek_target(seek_target),
                     .code_shift(code_shift),
                     .accumulator_updating(accumulator_updating),
                     .accumulator_i(accumulator_i),
                     .accumulator_q(accumulator_q),
                     .i2q2_valid(i2q2_valid),
                     .i2q2_early(i2q2_early),
                     .i2q2_prompt(i2q2_prompt),
                     .i2q2_late(i2q2_late),
                     .acquisition_complete(acquisition_complete),
                     .acq_peak_i2q2(acq_peak_i2q2),
                     .acq_peak_doppler(acq_peak_doppler),
                     .acq_peak_code_shift(acq_peak_code_shift),
                     .ca_bit(ca_bit),
                     .ca_clk(ca_clk),
                     .ca_code_shift(ca_code_shift));
endmodule