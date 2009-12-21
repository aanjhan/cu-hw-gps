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
`include "acquisition_controller.vh"
`include "channel__acquisition_controller.vh"
`include "acquisition.vh"

`define DEBUG
`include "debug.vh"

`undef DEBUG
`ifdef DEBUG

 //`undef MAX_CODE_SHIFT
 //`define MAX_CODE_SHIFT `CS_WIDTH'h1

 /*`undef DOPP_MAX_INC
 `define DOPP_MAX_INC `DOPPLER_INC_WIDTH'd6392

 `undef DOPP_EARLY_START
 `define DOPP_EARLY_START `DOPPLER_INC_WIDTH'd1598

 `undef DOPP_PROMPT_START
 `define DOPP_PROMPT_START `DOPPLER_INC_WIDTH'd0

 `undef DOPP_LATE_START
  `define DOPP_LATE_START -`DOPPLER_INC_WIDTH'd1598*/
 `undef DOPP_MAX_INC
 `define DOPP_MAX_INC `DOPPLER_INC_WIDTH'd7990

 `undef DOPP_EARLY_START
 `define DOPP_EARLY_START -`DOPPLER_INC_WIDTH'd4794

 `undef DOPP_PROMPT_START
 `define DOPP_PROMPT_START -`DOPPLER_INC_WIDTH'd6392

 `undef DOPP_LATE_START
 `define DOPP_LATE_START -`DOPPLER_INC_WIDTH'd7990
`endif //  `ifdef DEBUG

`define DOPP_START `DOPP_LATE_START

module acquisition_controller(
    input                            clk,
    input                            reset,
    //Acquisiton control.
    input                            start_acquisition,
    input                            frame_start,
    //Accumulator Doppler bins.
    output wire [`DOPPLER_INC_RANGE] doppler_0,
    output wire [`DOPPLER_INC_RANGE] doppler_1,
    output wire [`DOPPLER_INC_RANGE] doppler_2,
    //Code control.
    output wire                      seek_en,
    output reg [`CS_RANGE]           code_shift,
    input                            target_reached,
    //Accumulation results.
    input                            accumulation_complete,
    input                            i2q2_ready,
    input [`ACQ_ACC_SEL_RANGE]       i2q2_tag,
    input [`I2Q2_RANGE]              i2q2_value,
    //Acquisition results.
    output wire                      acquisition_complete,
    output wire                      satellite_acquired,
    output reg [`DOPPLER_INC_RANGE]  peak_doppler,
    output reg [`CS_RANGE]           peak_code_shift,
    //Debug.
    output reg [`I2Q2_RANGE]         peak_i2q2);

   `PRESERVE reg acq_active;
   wire start_acq;
   assign start_acq = start_acquisition && !acq_active;

   wire finished_early;
   `PRESERVE reg ignore_next_update;
   `PRESERVE reg feed_idle;
   `KEEP wire advance_code;
   `KEEP wire advance_doppler;
   `KEEP wire last_i2q2_received;
   `KEEP wire last_bin_pending;
   always @(posedge clk) begin
      //Determine when the feed is idle for seek enable usage.
      feed_idle <= reset ? 1'b1 :
                   start_acq ? 1'b0 :
                   frame_start ? 1'b0 :
                   accumulation_complete ? 1'b1 :
                   feed_idle;

      //Acquisition is active from when a start is flagged,
      //including the reset before the first update, until
      //the last I2Q2 values are received.
      //FIXME Is the update ignore necessary anymore?
      acq_active <= reset ? 1'b0 :
                    start_acq ? 1'b1 :
                    finished_early ? 1'b0 :
                    prev_last_bin_pending && last_i2q2_received ? 1'b0 :
                    acq_active;
      

      //Advance the code shift target to the next chip with
      //each completed update.
      code_shift <= start_acq ? `CS_WIDTH'h0 :
                    advance_code ? (cs_reset ?
                                    `CS_WIDTH'h0 :
                                    code_shift+`CS_WIDTH'h1) :
                    code_shift;

      //If still seeking when the data feed resets, continue
      //to seek and ignore the next accumulation result.
      ignore_next_update <= reset ? 1'b0 :
                            start_acq ? 1'b1 :
                            frame_start ? !target_reached :
                            ignore_next_update;
   end // always @ (posedge clk)

   //Seek the code to the next offset at the end of each
   //accumulation. Assert seek until feed starts.
   assign seek_en = feed_idle || ignore_next_update;

   strobe acq_complete_strobe(.clk(clk),
                              .reset(reset),
                              .in(!acq_active),
                              .out(acquisition_complete));

   //Report acquisition early if the peak value is beyond
   //the early completion threshold and the new value is
   //smaller than the peak value.
   assign finished_early = i2q2_ready &&
                           peak_i2q2>i2q2_value &&
                           peak_i2q2>=`ACQ_I2Q2_EARLY_THRESHOLD;

   //A satellite has been acquired as long as its peak I2Q2 value
   //is higher than the defined acquisition threshold.
   assign satellite_acquired = (acquisition_complete && peak_i2q2>=`ACQ_I2Q2_THRESHOLD) ||
                               finished_early;

   //Advance each accumulator's Doppler bin by (# acc)*bin width
   //after the accumulation has completed for the last code shift
   //search in a given Doppler bin.
   reg [`DOPPLER_INC_RANGE] doppler[0:(`ACQ_NUM_ACCUMULATORS-1)];
   genvar i;
   generate
      for(i=0;i<`ACQ_NUM_ACCUMULATORS;i=i+1) begin : dopp_gen
         always @(posedge clk) begin
            doppler[i] <= start_acq ? (`DOPP_START+(i*`DOPP_BIN_INC)) :
                          advance_doppler ? doppler[i]+`DOPP_ACQ_INC :
                          doppler[i];
         end
      end
   endgenerate

   //FIXME This should be preprocessor-assigned.
   assign doppler_0 = doppler[0];
   assign doppler_1 = doppler[1];
   assign doppler_2 = doppler[2];

   //Flag when the last bin is waiting for I2Q2 results.
   assign last_bin_pending = code_shift==`MAX_CODE_SHIFT &&
                             (!doppler[`ACQ_NUM_ACCUMULATORS-1][`DOPPLER_INC_WIDTH-1] && doppler[`ACQ_NUM_ACCUMULATORS-1]>=`DOPP_MAX_INC);

   //Reset code shift after hitting maximum value.
   wire cs_reset;
   assign cs_reset = code_shift==`MAX_CODE_SHIFT;

   //Only advance the current code shift and Doppler
   //when a currently active accumulation finishes.
   assign advance_code = acq_active &&
                         !ignore_next_update &&
                         accumulation_complete &&
                         !last_bin_pending;

   //Advance to the next Doppler bins after the
   //update has completed for the last code shift
   //search in a given Doppler bin.
   assign advance_doppler = advance_code && cs_reset;

   //Store previous bin information for update state machine.
   reg [`DOPPLER_INC_RANGE] prev_doppler[0:(`ACQ_NUM_ACCUMULATORS-1)];
   reg [`CS_RANGE]          prev_code_shift;
   reg                      prev_ignore_update;
   reg                      prev_last_bin_pending;
   reg                      prev_acq_active;
   generate
      for(i=0;i<`ACQ_NUM_ACCUMULATORS;i=i+1) begin : prev_dopp_gen
         always @(posedge clk) begin
            prev_doppler[i] <= accumulation_complete ? doppler[i] : prev_doppler[i];
         end
      end
   endgenerate
   always @(posedge clk) begin
      if(accumulation_complete) begin
         prev_code_shift <= code_shift;
         prev_ignore_update <= ignore_next_update;
         prev_last_bin_pending <= last_bin_pending;
         prev_acq_active <= acq_active;
      end
      else if(finished_early) begin
         prev_acq_active <= 1'b0;
      end
   end

   //Store peak value and search parameters at the
   //end of each code shift search. Update values
   //only if new peak I2Q2 value > old peak.
   //`PRESERVE reg [`I2Q2_RANGE] peak_i2q2;
   always @(posedge clk) begin
      if(reset || start_acq) begin
         peak_i2q2 <= `I2Q2_WIDTH'd0;
         peak_code_shift <= `CS_WIDTH'd0;
         peak_doppler <= `DOPPLER_INC_WIDTH'd0;
      end
      else if(prev_acq_active && i2q2_ready && !prev_ignore_update) begin
         if(peak_i2q2<i2q2_value) begin
            peak_i2q2 <= i2q2_value;
            peak_code_shift <= prev_code_shift;
            peak_doppler <= prev_doppler[i2q2_tag];
         end
      end
   end // always @ (posedge clk)

   //Flag when the last I2Q2 value is received from the accumulators.
   assign last_i2q2_received = prev_acq_active &&
                               i2q2_ready &&
                               !prev_ignore_update &&
                               i2q2_tag==(`ACQ_ACC_SEL_MAX-`ACQ_ACC_SEL_WIDTH'd1);
   
endmodule // acquisition_controller