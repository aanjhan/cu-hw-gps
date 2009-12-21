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
`include "ca_upsampler.vh"
`include "channel__ca_upsampler.vh"

//`define DEBUG
`include "debug.vh"

module ca_initializer(
    input                            clk,
    input                            reset,
    //Control interface.
    input [`PRN_RANGE]               prn,
    input [`CS_RANGE]                seek_target,
    output wire                      seek_complete,
    //C/A upsampler state.
    output reg [`CA_ACC_RANGE]       ca_clk_acc,
    output reg                       ca_clk_hist,
    output reg [`CA_CHIP_HIST_RANGE] prompt_chip_hist,
    output reg [`CA_CHIP_HIST_RANGE] late_chip_hist,
    //C/A generator state.
    output reg [10:1]                g1,
    output reg [10:1]                g2);

   `KEEP wire [`CS_RANGE] next_code_shift;
   `PRESERVE reg [`CS_RANGE] code_shift;
   assign next_code_shift = (code_shift==`MAX_CODE_SHIFT ?
                             `CS_WIDTH'd0 :
                             code_shift+`CS_WIDTH'd1);
   
   wire target_reached;
   assign target_reached = next_code_shift==seek_target;

   wire target_reached_km1;
   delay tr_delay(.clk(clk),
                  .reset(reset),
                  .in(target_reached),
                  .out(target_reached_km1));

   //Seek is only complete when the target has
   //been reached and the C/A generator is finished
   //updating. Checking target_reached allows the
   //target to be changed after it has been reached.
   assign seek_complete = code_shift==seek_target;

   wire enable;
   assign enable = !target_reached && !seek_complete;

   //Note: The code shift corresponds to the prompt
   //      output, and is one cycle behind the seek.
   `KEEP wire enable_km1;
   always @(posedge clk) begin
      code_shift <= reset ? `CS_RESET_VALUE :
                    enable_km1 ? next_code_shift :
                    code_shift;
   end
   
   //Generate C/A code clock from reference
   //clock signal.
   `KEEP wire ca_clk_n;
   wire [`CA_ACC_RANGE] ca_clk_acc_out;
   dds_sw #(.ACC_WIDTH(`CA_ACC_WIDTH),
            .PHASE_INC_WIDTH(`CA_PHASE_INC_WIDTH),
            .OUTPUT_WIDTH(1))
     ca_clock_gen(.clk(clk),
                  .reset(reset),
                  .enable(1'b1),
                  .inc(`CA_RATE_INC),
                  .out(ca_clk_n),
                  .acc_in(ca_clk_acc),
                  .acc_out(ca_clk_acc_out));
   always @(posedge clk) begin
      ca_clk_acc <= reset || enable ?
                    ca_clk_acc_out :
                    ca_clk_acc;
   end

   //Strobe C/A clock for 1 cycle.
   wire ca_clk;
   wire ca_clk_hist_out;
   strobe_sw #(.RESET_ONE(1))
     ca_strobe(.clk(clk),
               .reset(reset),
               .in(~ca_clk_n),
               .out(ca_clk),
               .hist_in(ca_clk_hist),
               .hist_out(ca_clk_hist_out));
   always @(posedge clk) begin
      ca_clk_hist <= reset || enable ?
                     ca_clk_hist_out :
                     ca_clk_hist;
   end

   //Delay C/A generator clock 1 cycle to meet timing.
   `KEEP wire ca_clk_km1;
   delay ca_clk_delay(.clk(clk),
                      .reset(reset),
                      .in(ca_clk),
                      .out(ca_clk_km1));

   delay enable_delay(.clk(clk),
                      .reset(reset),
                      .in(enable),
                      .out(enable_km1));

   //Generate C/A code bit for given PRN.
   `KEEP wire out_early;
   wire [10:1] g1_out;
   wire [10:1] g2_out;
   ca_generator_sw ca_gen(.reset(reset),
                          .enable(ca_clk_km1),
                          .prn(prn),
                          .out(out_early),
                          .g1_in(g1),
                          .g2_in(g2),
                          .g1_out(g1_out),
                          .g2_out(g2_out));
   always @(posedge clk) begin
      g1 <= reset || enable_km1 ? g1_out : g1;
      g2 <= reset || enable_km1 ? g2_out : g2;
   end

   //Generate prompt and late codes by delaying
   //early code by CHIPS_LEAD_LAG. Outputs are
   //delayed one cycle to align with output from
   //C/A generator.

   `KEEP wire out_prompt;
   wire [`CA_CHIP_HIST_RANGE] prompt_chip_hist_out;
   assign prompt_chip_hist_out = {prompt_chip_hist[(`CA_CHIP_HIST_WIDTH-2):0],out_early};
   assign out_prompt = prompt_chip_hist[`CA_CHIP_HIST_WIDTH-1];
   always @(posedge clk) begin
      prompt_chip_hist <= reset ? `CA_CHIP_HIST_WIDTH'h0 :
                          enable_km1 ? prompt_chip_hist_out :
                          prompt_chip_hist;
   end

   wire [`CA_CHIP_HIST_RANGE] late_chip_hist_out;
   assign late_chip_hist_out = {late_chip_hist[(`CA_CHIP_HIST_WIDTH-2):0],out_prompt};
   always @(posedge clk) begin
      late_chip_hist <= reset ? `CA_CHIP_HIST_WIDTH'h0 :
                        enable_km1 ? late_chip_hist_out :
                        late_chip_hist;
   end
   
endmodule