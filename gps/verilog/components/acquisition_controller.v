`include "global.vh"
`include "acquisition_controller.vh"
`include "channel__acquisition_controller.vh"

`define DEBUG
`include "debug.vh"
//`define DEBUG

`ifdef DEBUG
 //`undef MAX_CODE_SHIFT
 //`define MAX_CODE_SHIFT `CS_WIDTH'h0

 `undef DOPP_MAX_INC
 `define DOPP_MAX_INC `DOPPLER_INC_WIDTH'd6392

 `undef DOPP_EARLY_START
 `define DOPP_EARLY_START `DOPPLER_INC_WIDTH'd1598

 `undef DOPP_PROMPT_START
 `define DOPP_PROMPT_START `DOPPLER_INC_WIDTH'd0

 `undef DOPP_LATE_START
 `define DOPP_LATE_START -`DOPPLER_INC_WIDTH'd1598
`endif

module acquisition_controller(
    input                           clk,
    input                           global_reset,
    //Acquisiton control.
    input                           start_acquisition,
    input                           frame_start,
    output reg [`DOPPLER_INC_RANGE] doppler_early,
    output reg [`DOPPLER_INC_RANGE] doppler_prompt,
    output reg [`DOPPLER_INC_RANGE] doppler_late,
    output reg                      seek_en,
    output reg [`CS_RANGE]          code_shift,
    input                           target_reached,
    //Accumulation results.
    input                           accumulation_complete,
    input                           i2q2_valid,
    input [`I2Q2_RANGE]             i2q2_early,
    input [`I2Q2_RANGE]             i2q2_prompt,
    input [`I2Q2_RANGE]             i2q2_late,
    //Acquisition results.
    output reg                      acquisition_complete,
    output reg [`I2Q2_RANGE]        peak_i2q2,
    output reg [`DOPPLER_INC_RANGE] peak_doppler,
    output reg [`CS_RANGE]          peak_code_shift);

   `PRESERVE reg acq_active;
   `PRESERVE reg ignore_next_update;
   `PRESERVE reg feed_idle;
   `KEEP reg update_complete;
   `KEEP wire advance_code;
   `KEEP wire advance_doppler;
   `KEEP wire last_bin_pending;
   always @(posedge clk) begin
      //Determine when the feed is idle for seek enable usage.
      feed_idle <= global_reset ? 1'b1 :
                   frame_start ? 1'b0 :
                   accumulation_complete ? 1'b1 :
                   feed_idle;

      //Acquisition is active from when a start is flagged,
      //including the reset before the first update, until
      //the last I2Q2 values are received.
      acq_active <= global_reset ? 1'b0 :
                    start_acquisition ? 1'b1 :
                    last_bin_pending && accumulation_complete && !ignore_next_update ? 1'b0 :
                    acq_active;

      //Seek the code to the next offset at the end of each
      //accumulation. Only disable seek enable when the feed
      //is idle so the C/A upsampler doesn't continue to chip
      //while we are waiting for feed to complete.
      seek_en <= global_reset ? 1'b0 :
                 start_acquisition ? 1'b1 :
                 accumulation_complete ? 1'b1 :
                 target_reached && feed_idle ? 1'b0 :
                 seek_en;
      

      //Advance the code shift target to the next chip with
      //each completed update.
      code_shift <= start_acquisition ? `CS_WIDTH'h0 :
                    advance_code ? (cs_reset ?
                                    `CS_WIDTH'h0 :
                                    code_shift+`CS_WIDTH'h1) :
                    code_shift;
      
      //Update Doppler shifts after the update has completed
      //for the last code shift search in a given Doppler bin.
      doppler_early <= start_acquisition ? `DOPP_EARLY_START :
                       advance_doppler ? doppler_early+`DOPP_ACQ_INC :
                       doppler_early;
      
      doppler_prompt <= start_acquisition ? `DOPP_PROMPT_START :
                        advance_doppler ? doppler_prompt+`DOPP_ACQ_INC :
                        doppler_prompt;
      
      doppler_late <= start_acquisition ? `DOPP_LATE_START :
                      advance_doppler ? doppler_late+`DOPP_ACQ_INC :
                      doppler_late;

      //If still seeking when the data feed resets, continue
      //to seek and ignore the next accumulation result.
      ignore_next_update <= global_reset ? 1'b0 :
                            start_acquisition ? 1'b1 :
                            frame_start && seek_en ? 1'b1 :
                            accumulation_complete ? 1'b0 :
                            ignore_next_update;

      //Acquisition has finished once the last Doppler bins'
      //results are returned by the update state machine.
      acquisition_complete <= global_reset ? 1'b0 :
                              start_acquisition ? 1'b0 :
                              !acq_active && update_complete ? 1'b1 :
                              acquisition_complete;
   end // always @ (posedge clk)

   //Flag when the last bin is waiting for I2Q2 results.
   assign last_bin_pending = code_shift==`MAX_CODE_SHIFT &&
                             doppler_early>=`DOPP_MAX_INC;

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
   reg [`DOPPLER_INC_RANGE] prev_doppler_early;
   reg [`DOPPLER_INC_RANGE] prev_doppler_prompt;
   reg [`DOPPLER_INC_RANGE] prev_doppler_late;
   reg [`CS_RANGE]          prev_code_shift;
   reg                      prev_ignore_update;
   reg                      prev_acq_active;
   always @(posedge clk) begin
      if(accumulation_complete) begin
         prev_doppler_early <= doppler_early;
         prev_doppler_prompt <= doppler_prompt;
         prev_doppler_late <= doppler_late;
         prev_code_shift <= code_shift;
         prev_ignore_update <= ignore_next_update;
         prev_acq_active <= acq_active;
      end
   end
   
   //Store peak value and search parameters at the
   //end of each code shift search. Update values
   //only if new peak I2Q2 value > old peak.
   `PRESERVE reg [`I2Q2_RANGE] new_value;
   `PRESERVE reg [1:0] subchannel_select;
   `PRESERVE reg [`ACQ_STATE_RANGE] update_state;
   always @(posedge clk) begin
      if(global_reset || start_acquisition) begin
         update_state <= `ACQ_STATE_IDLE;
         update_complete <= 1'b0;
              
         peak_i2q2 <= `I2Q2_WIDTH'd0;
         peak_code_shift <= `CS_WIDTH'd0;
         peak_doppler <= `DOPPLER_INC_WIDTH'd0;
      end
      else begin
         case(update_state)
           //Compare i2q2_early and i2q2_prompt. If we are
           //ignoring this update, flag update complete and
           //return to idle.
           `ACQ_STATE_EARLY_PROMPT: begin
              update_state <= prev_ignore_update ?
                              `ACQ_STATE_IDLE :
                              `ACQ_STATE_EP_LATE;
              update_complete <= prev_ignore_update;
              
              new_value <= i2q2_early>i2q2_prompt ?
                           i2q2_early :
                           i2q2_prompt;
              subchannel_select <= i2q2_early>i2q2_prompt ?
                                   2'd0 :
                                   2'd1;
           end
           //Compare i2q2_late and previous result.
           `ACQ_STATE_EP_LATE: begin
              update_state <= `ACQ_STATE_PEAK;
              new_value <= i2q2_late>new_value ?
                           i2q2_late :
                           new_value;
              subchannel_select <= i2q2_late>new_value ?
                                   2'd2 :
                                   subchannel_select;
           end
           //Compare result to previous peak value.
           `ACQ_STATE_PEAK: begin
              update_state <= new_value>peak_i2q2 ?
                              `ACQ_STATE_UPDATE :
                              `ACQ_STATE_IDLE;
           end
           //New peak found - update results.
           `ACQ_STATE_UPDATE: begin
              update_state <= `ACQ_STATE_IDLE;
              update_complete <= 1'b1;
              
              peak_i2q2 <= new_value;
              peak_code_shift <= prev_code_shift;
              peak_doppler <= subchannel_select==2'd0 ? prev_doppler_early :
                              subchannel_select==2'd1 ? prev_doppler_prompt :
                              prev_doppler_late;
           end
           //Idle. Wait for next valid accumulation to complete.
           default: begin
              update_state <= prev_acq_active &&
                              i2q2_valid &&
                              !acquisition_complete ?
                              `ACQ_STATE_EARLY_PROMPT :
                              `ACQ_STATE_IDLE;
              update_complete <= 1'b0;
           end
         endcase
      end
   end // always @ (posedge clk)
   
endmodule // acquisition_controller