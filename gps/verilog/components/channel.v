`include "global.vh"
`include "channel.vh"
`include "channel__subchannel.vh"
`include "top__channel.vh"

module channel(
    input                      clk,
    input                      global_reset,
    input                      reset,
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
    output wire [`CS_RANGE]    code_shift,
    //Outputs.
    output wire [`ACC_RANGE]   accumulator_i,
    output wire [`ACC_RANGE]   accumulator_q,
    output reg                 i2q2_prompt_valid,
    output reg [`I2Q2_RANGE]   i2q2_prompt,
    //Debug outputs.
    output wire                ca_bit,
    output wire                ca_clk,
    output wire [9:0]          ca_code_shift);
   
   //Prompt subchannel.
   wire accumulator_updating;
   subchannel prompt(.clk(clk),
                     .global_reset(global_reset),
                     .reset(reset),
                     .data_available(data_available),
                     .data(data),
                     .doppler(doppler),
                     .prn(prn),
                     .seek_en(seek_en),
                     .seek_target(seek_target),
                     .code_shift(code_shift),
                     .accumulator_updating(accumulator_updating),
                     .accumulator_i(accumulator_i),
                     .accumulator_q(accumulator_q),
                     .ca_bit(ca_bit),
                     .ca_clk(ca_clk),
                     .ca_code_shift(ca_code_shift));

   reg [15:0] sample_count;
   always @(posedge clk) begin
      sample_count <= reset ? 16'h0 :
                      accumulator_updating ? sample_count + 16'h1 :
                      sample_count;
   end

   wire feed_complete_kmn;
   delay #(.DELAY(6))
     feed_complete_delay(.clk(clk),
                         .reset(global_reset),
                         .in(feed_complete),
                         .out(feed_complete_kmn));

   wire acc_complete;
   strobe acc_complete_strobe(.clk(clk),
                              .reset(reset),
                              .in(feed_complete_kmn),//FIXME feed_complete || track acc done
                              .out(acc_complete));

   wire [`ACC_MAG_RANGE] i_prompt_mag;
   abs #(.WIDTH(`ACC_WIDTH))
     abs_i_prompt(.in(accumulator_i),
                  .out(i_prompt_mag));

   wire [`ACC_MAG_RANGE] q_prompt_mag;
   abs #(.WIDTH(`ACC_WIDTH))
     abs_q_prompt(.in(accumulator_q),
                  .out(q_prompt_mag));
   
   reg [`ACC_MAG_RANGE] i_prompt, q_prompt;
   reg acc_ready;
   always @(posedge clk) begin
      i_prompt <= global_reset ? `ACC_MAG_WIDTH'h0 :
                  acc_complete ? i_prompt_mag :
                  i_prompt;
      
      q_prompt <= global_reset ? `ACC_MAG_WIDTH'h0 :
                  acc_complete ? q_prompt_mag :
                  q_prompt;

      acc_ready <= global_reset ? 1'b0 :
                   acc_complete ? 1'b1 :
                   1'b0;
   end // always @ (posedge clk)

   wire [`I2Q2_RANGE] i2_prompt;
   multiplier i2_mult(.clock(clk),
                      .dataa(i_prompt),
                      .result(i2_prompt));
   
   wire [`I2Q2_RANGE] q2_prompt;
   multiplier q2_mult(.clock(clk),
                      .dataa(q_prompt),
                      .result(q2_prompt));

   (* keep *) wire [`I2Q2_RANGE] i2_prompt_kmn;
   delay #(.WIDTH(`I2Q2_WIDTH),
           .DELAY(1))
     i2_prompt_delay(.clk(clk),
                     .reset(global_reset),
                     .in(i2_prompt),
                     .out(i2_prompt_kmn));
   
   (* keep *) wire [`I2Q2_RANGE] q2_prompt_kmn;
   delay #(.WIDTH(`I2Q2_WIDTH),
           .DELAY(1))
     q2_prompt_delay(.clk(clk),
                     .reset(global_reset),
                     .in(q2_prompt),
                     .out(q2_prompt_kmn));

   wire square_complete;
   delay #(.DELAY(5))
     square_delay(.clk(clk),
                  .reset(global_reset),
                  .in(acc_ready),
                  .out(square_complete));
   
   wire [`I2Q2_RANGE] i2q2_out;
   assign i2q2_out = i2_prompt_kmn+q2_prompt_kmn;

   always @(posedge clk) begin
      i2q2_prompt_valid <= global_reset ? 1'b0 :
                           square_complete ? 1'b1 :
                           i2q2_prompt_valid;
      
      i2q2_prompt <= global_reset ? `I2Q2_WIDTH'h0 :
                     square_complete ? i2q2_out :
                     i2q2_prompt;
   end
   
endmodule