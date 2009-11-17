`include "global.vh"
`include "ca_upsampler.vh"
`include "channel__ca_upsampler.vh"

`define DEBUG
`include "debug.vh"

module ca_upsampler_sw(
    input                             clk,
    input                             reset,
    //Control interface.
    input [`PRN_RANGE]                prn,
    input [`CA_PHASE_INC_RANGE]       ca_dphi,
    //C/A code output interface.
    output wire                       out_early,
    output wire                       out_prompt,
    output wire                       out_late,
    //C/A upsampler state.
    input [`CS_RANGE]                 code_shift_in,
    input [`CA_ACC_RANGE]             ca_clk_acc_in,
    input                             ca_clk_hist_in,
    input [`CA_CHIP_HIST_RANGE]       prompt_chip_hist_in,
    input [`CA_CHIP_HIST_RANGE]       late_chip_hist_in,
    output wire [`CS_RANGE]           code_shift_out,
    output wire [`CA_ACC_RANGE]       ca_clk_acc_out,
    output wire                       ca_clk_hist_out,
    output wire [`CA_CHIP_HIST_RANGE] prompt_chip_hist_out,
    output wire [`CA_CHIP_HIST_RANGE] late_chip_hist_out,
    //C/A generator state.
    input [10:1]                      g1_in,
    input [10:1]                      g2_in,
    input [`CA_CS_RANGE]              ca_code_shift_in,
    output wire [10:1]                g1_out,
    output wire [10:1]                g2_out,
    output wire [`CA_CS_RANGE]        ca_code_shift_out,
    //Debug outputs.
    output wire                       ca_clk);

   //Update code shift. Wrap shift at maximum chip count.
   assign code_shift_out = code_shift_in==`MAX_CODE_SHIFT ?
                           `CS_WIDTH'd0 :
                           (code_shift_in+`CS_WIDTH'd1);
   
   //Generate C/A code clock from reference
   //clock signal.
   `KEEP wire ca_clk_n;
   dds_sw #(.ACC_WIDTH(`CA_ACC_WIDTH),
            .PHASE_INC_WIDTH(`CA_PHASE_INC_WIDTH),
            .OUTPUT_WIDTH(1))
     ca_clock_gen(.clk(clk),
                  .reset(reset),
                  .enable(1'b1),
                  .inc(`CA_RATE_INC+ca_dphi),
                  .out(ca_clk_n),
                  .acc_in(ca_clk_acc_in),
                  .acc_out(ca_clk_acc_out));

   //Strobe C/A clock for 1 cycle.
   //FIXME Is this necessary if using a switching channel?
   strobe_sw #(.RESET_ONE(1))
     ca_strobe(.clk(clk),
               .reset(reset),
               .in(~ca_clk_n),
               .out(ca_clk),
               .hist_in(ca_clk_hist_in),
               .hist_out(ca_clk_hist_out));

   //Delay C/A generator clock 1 cycle to meet timing.
   `KEEP wire ca_clk_km1;
   delay ca_clk_delay(.clk(clk),
                      .reset(reset),
                      .in(ca_clk),
                      .out(ca_clk_km1));

   //FIXME Can all of these delays be eliminated,
   //FIXME or at least the PRN delay, and pushed
   //FIXME to a mux at the top level?
   `KEEP wire [`PRN_RANGE] prn_km1;
   delay #(.WIDTH(`PRN_WIDTH))
     prn_delay(.clk(clk),
              .reset(reset),
              .in(prn),
              .out(prn_km1));
   
   `KEEP wire [10:1] g1_km1;
   delay #(.WIDTH(10))
     g1_delay(.clk(clk),
              .reset(reset),
              .in(g1_in),
              .out(g1_km1));
   
   `KEEP wire [10:1]  g2_km1;
   delay #(.WIDTH(10))
     g2_delay(.clk(clk),
              .reset(reset),
              .in(g2_in),
              .out(g2_km1));
   
   `KEEP wire [`CA_CS_RANGE] ca_cs_km1;
   delay #(.WIDTH(`CA_CS_WIDTH))
     ca_cs_delay(.clk(clk),
                 .reset(reset),
                 .in(ca_code_shift_in),
              .out(ca_cs_km1));

   //Generate C/A code bit for given PRN.
   ca_generator_sw ca_gen(.enable(ca_clk_km1),
                          .prn(prn_km1),
                          .out(out_early),
                          .g1_in(g1_km1),
                          .g2_in(g2_km1),
                          .code_shift_in(ca_cs_km1),
                          .g1_out(g1_out),
                          .g2_out(g2_out),
                          .code_shift_out(ca_code_shift_out));

   //Generate prompt and late codes by delaying
   //early code by CHIPS_LEAD_LAG. Outputs are
   //delayed one cycle to align with output from
   //C/A generator.
   
   wire [`CA_CHIP_HIST_RANGE] prompt_chip_hist_km1;
   delay #(.WIDTH(`CA_CHIP_HIST_WIDTH))
     prompt_hist_delay(.clk(clk),
                       .reset(reset),
                       .in(prompt_chip_hist_in),
                       .out(prompt_chip_hist_km1));
   assign prompt_chip_hist_out = {prompt_chip_hist_km1[(`CA_CHIP_HIST_WIDTH-2):0],out_early};
   assign out_prompt = prompt_chip_hist_km1[`CA_CHIP_HIST_WIDTH-1];
   
   wire [`CA_CHIP_HIST_RANGE] late_chip_hist_km1;
   delay #(.WIDTH(`CA_CHIP_HIST_WIDTH))
     late_hist_delay(.clk(clk),
                     .reset(reset),
                     .in(late_chip_hist_in),
                     .out(late_chip_hist_km1));
   assign late_chip_hist_out = {late_chip_hist_km1[(`CA_CHIP_HIST_WIDTH-2):0],out_prompt};
   assign out_late = late_chip_hist_km1[`CA_CHIP_HIST_WIDTH-1];
   
endmodule