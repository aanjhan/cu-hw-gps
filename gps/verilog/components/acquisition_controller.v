`include "global.vh"
`include "acquisition_controller.vh"
`include "channel__acquisition_controller.vh"

//`define DEBUG
`ifdef DEBUG
 `define KEEP (* keep *)
 `define PRESERVE (* preserve *)
`else
 `define KEEP
 `define PRESERVE
`endif

`ifdef DEBUG
`undef MAX_CODE_SHIFT
`define MAX_CODE_SHIFT `CS_WIDTH'h2

`undef DOPP_MAX_INC
`define DOPP_MAX_INC -`DOPPLER_INC_WIDTH'd39945
`endif

module acquisition_controller(
    input                           clk,
    input                           global_reset,
    //Acquisiton control.
    input [`MODE_RANGE]             mode,
    output reg [`DOPPLER_INC_RANGE] doppler_early,
    output reg [`DOPPLER_INC_RANGE] doppler_prompt,
    output reg [`DOPPLER_INC_RANGE] doppler_late,
    output reg                      seek_en,
    output reg [`CS_RANGE]          code_shift,
    input                           seeking,
    //Accumulation results.
    input                           accumulation_complete,
    input                           i2q2_valid,
    input [`I2Q2_RANGE]             i2q2_early,
    input [`I2Q2_RANGE]             i2q2_prompt,
    input [`I2Q2_RANGE]             i2q2_late,
    //Acquisition results.
    output wire                     acquisition_complete,
    output reg [`I2Q2_RANGE]        peak_i2q2,
    output reg [`DOPPLER_INC_RANGE] peak_doppler,
    output reg [`CS_RANGE]          peak_code_shift);

   //Prompt an acquisition start when the channel mode
   //is switched to acquisition. Wait until data feed
   //resets to start.
   `KEEP wire start_acq;
   strobe #(.RESET_ZERO(1))
     start_acq_strobe(.clk(clk),
                      .reset(global_reset),
                      .in(mode==`MODE_ACQ),
                      .out(start_acq));

   `KEEP wire restarting;
   flag start_flag(.clk(clk),
                   .reset(global_reset),
                   .clear(accumulation_complete),
                   .set(start_acq),
                   .out(restarting));

   `KEEP wire acq_active;
   flag acq_active_flag(.clk(clk),
                        .reset(global_reset),
                        .clear(acquisition_complete && !start_acq),
                        .set(start_acq),
                        .out(acq_active));

   wire acc_complete_km1;
   delay acc_complete_delay(.clk(clk),
                            .reset(global_reset),
                            .in(accumulation_complete),
                            .out(acc_complete_km1));

   wire seek_complete;
   assign seek_complete = !seeking && acc_complete_km1;
   
   //A single search is active when its seek target has
   //been reached immediately following the completion
   //of an accumulation.
   reg active;
   always @(posedge clk) begin
      active <= global_reset ? 1'b0 :
                !acq_active ? 1'b0 :
                seek_en && seek_complete ? 1'b1 :
                accumulation_complete ? 1'b0 :
                active;
   end

   reg ignore_return;
   always @(posedge clk) begin
      ignore_return <= global_reset ? 1'b0 :
                       !active && i2q2_valid ? 1'b1 :
                       i2q2_valid ? 1'b0 :
                       ignore_return;
   end

   //Only advance the current code shift and Doppler
   //when a currently active accumulation finishes.
   wire advance;
   assign advance = active && accumulation_complete;

   //Reset code shift after hitting maximum value.
   wire cs_reset;
   assign cs_reset = code_shift==`MAX_CODE_SHIFT;

   //Update code shift and seek to new target after
   //each accumulation finishes. Seek is enabled for
   //an entire data feed period if it is not ready
   //right away to stop the code generator from updating
   //when inactive.
   always @(posedge clk) begin
      seek_en <= accumulation_complete ? 1'b1 :
                 seek_complete ? 1'b0 :
                 seek_en;
      
      code_shift <= restarting ? `CS_WIDTH'h0 :
                    advance ? (cs_reset ?
                               `CS_WIDTH'h0 :
                               code_shift+`CS_WIDTH'h1) :
                    code_shift;
   end

   //Update Doppler shifts at beginning of each
   //accumulation after a code shift search completion.
   wire update_doppler;
   assign update_doppler = advance && cs_reset;

   always @(posedge clk) begin
      doppler_early <= restarting ? `DOPP_EARLY_START :
                       update_doppler ? doppler_early+`DOPP_ACQ_INC :
                       doppler_early;
      
      doppler_prompt <= restarting ? `DOPP_PROMPT_START :
                        update_doppler ? doppler_prompt+`DOPP_ACQ_INC :
                        doppler_prompt;
      
      doppler_late <= restarting ? `DOPP_LATE_START :
                      update_doppler ? doppler_late+`DOPP_ACQ_INC :
                      doppler_late;
   end // always @ (posedge clk)

   //Store parameters from most recent search.
   reg [`CS_RANGE] prev_code_shift;
   reg [`DOPPLER_INC_RANGE] prev_doppler_early, prev_doppler_prompt, prev_doppler_late;
   always @(posedge clk) begin
      prev_code_shift <= advance ? code_shift : prev_code_shift;
      prev_doppler_early <= advance ? doppler_early : prev_doppler_early;
      prev_doppler_prompt <= advance ? doppler_prompt : prev_doppler_prompt;
      prev_doppler_late <= advance ? doppler_late : prev_doppler_late;
   end

   reg ignore_update;
   always @(posedge clk) begin
      ignore_update <= global_reset ? 1'b0 :
                       restarting ? 1'b1 :
                       !active && i2q2_valid ? 1'b1 :
                       i2q2_valid ? 1'b0 :
                       ignore_update;
   end

   `KEEP wire peak_update_pending;
   flag peak_update_flag(.clk(clk),
                         .reset(global_reset),
                         .clear(i2q2_valid),
                         .set(accumulation_complete &&
                              !ignore_update &&
                              acq_active),
                         .out(peak_update_pending));
   
   //Store peak value and search parameters at the
   //end of each code shift search. Update values
   //only if new peak I2Q2 value > old peak.
   //Note: this hardware is pipelined to meet timing,
   //but makes the assumption that the I2Q2 values will
   //be held constant throughout the process. It also
   //assumes that the data sequence is long enough
   //that the prev_* signals won't change.
   `PRESERVE reg [1:0] update_step;
   `PRESERVE reg [1:0] i2q2_sel;
   `KEEP wire update_completing;
   assign update_completing = i2q2_sel==2'h2 && update_step==2'h2;
   
   `KEEP wire peak_updating;
   flag updating_flag(.clk(clk),
                      .reset(global_reset),
                      .clear(update_completing),
                      .set(peak_update_pending && i2q2_valid),
                      .out(peak_updating));

   always @(posedge clk) begin
      //Step 0 - select next value.
      //Step 1 - compare to current peak.
      //Step 2 - update peak if necessary.
      update_step <= peak_update_pending ? 1'b0 :
                     peak_updating ? (update_step==2'h2 ? 2'h0 : update_step+2'h1) :
                     update_step;

      //0 - early, 1 - prompt, 2 - late.
      i2q2_sel <= peak_update_pending ? 2'h0 :
                  peak_updating && update_step==2'h2 ? i2q2_sel+2'h1 :
                  i2q2_sel;
   end

   `KEEP wire new_peak;
   `PRESERVE reg greater_value;
   `PRESERVE reg [`I2Q2_RANGE] next_value;
   always @(posedge clk) begin
      //Step 0 - select next value.
      next_value <= !peak_updating || update_step!=2'h0 ? next_value :
                    i2q2_sel==2'h0 ? i2q2_early :
                    i2q2_sel==2'h1 ? i2q2_prompt :
                    i2q2_late;
                    
      //Step 1 - compare to current peak.
      greater_value <= next_value>peak_i2q2;
      
      //Step 2 - update peak if necessary.
      peak_i2q2 <= restarting ? `I2Q2_WIDTH'h0 :
                   new_peak ? next_value :
                   peak_i2q2;
      
      peak_code_shift <= restarting ? `CS_WIDTH'h0 :
                         new_peak ? prev_code_shift :
                         peak_code_shift;
      
      peak_doppler <= restarting ? `DOPPLER_INC_WIDTH'h0 :
                      !new_peak ? peak_doppler :
                      i2q2_sel==2'h0 ? prev_doppler_early :
                      i2q2_sel==2'h1 ? prev_doppler_prompt :
                      prev_doppler_late;
   end // always @ (posedge clk)
   assign new_peak = greater_value && peak_updating && update_step==2'h2;

   wire update_complete;
   delay update_complete_delay(.clk(clk),
                               .reset(global_reset),
                               .in(update_completing),
                               .out(update_complete));
   
   //Acquisition has completed after the results
   //are in for the last code shift on the maximum
   //Doppler bin.
   flag acq_complete_flag(.clk(clk),
                          .reset(global_reset),
                          .clear(restarting),
                          .set(prev_code_shift==`MAX_CODE_SHIFT &&
                               prev_doppler_early>=`DOPP_MAX_INC &&
                               update_complete),
                          .out(acquisition_complete));
endmodule