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
`include "subchannel.vh"
`include "channel.vh"
`include "acquisition.vh"

module acquisition_unit(
    input                            clk,
    input                            reset,
    //Memory bank sample interface.
    input                            mem_data_available,
    input [`INPUT_RANGE]             mem_data,
    input                            frame_start,
    input                            frame_end,
    //Acquisition control.
    input                            start,
    input [`PRN_RANGE]               prn,
    output reg                       in_progress,
    //Acquisition results.
    output wire                      acquisition_complete,
    output wire                      satellite_acquired,
    output reg [`PRN_RANGE]          acq_prn,
    output wire [`DOPPLER_INC_RANGE] acq_peak_doppler,
    output wire [`CS_RANGE]          acq_peak_code_shift,
    //Debug.
    output wire [`I2Q2_RANGE]        acq_peak_i2q2);

   //Start the next acquisition as soon as possible.
   wire start_acq;
   assign start_acq = start && !in_progress;

   always @(posedge clk) begin
      acq_prn <= reset ? `PRN_WIDTH'd0 :
                 start_acq ? prn :
                 acq_prn;

      in_progress <= reset ? 1'b0 :
                     start ? 1'b1 :
                     acquisition_complete ? 1'b0 :
                     in_progress;
   end
   
   //Acquisition controller.
   //FIXME The Doppler bins should be assigned/connected to the acq_controller
   //FIXME by the preprocessor. Currently, they must be manually modified.
   `KEEP wire [`DOPPLER_INC_RANGE] acq_dopp[0:(`ACQ_NUM_ACCUMULATORS-1)];
   `KEEP wire                      acq_seek_en;
   `KEEP wire [`CS_RANGE]          acq_seek_target;
   wire accumulation_complete;
   `KEEP wire                      target_reached;
   `KEEP wire i2q2_ready;
   `PRESERVE reg [`ACQ_ACC_SEL_RANGE] i2q2_tag;
   `PRESERVE reg [`I2Q2_RANGE] i2q2_out;
   acquisition_controller acq_controller(.clk(clk),
                                         .reset(reset),
                                         .start_acquisition(start_acq),
                                         .frame_start(frame_start),
                                         .doppler_0(acq_dopp[0]),
                                         .doppler_1(acq_dopp[1]),
                                         .doppler_2(acq_dopp[2]),
                                         .seek_en(acq_seek_en),
                                         .code_shift(acq_seek_target),
                                         .target_reached(target_reached),
                                         .accumulation_complete(accumulation_complete),
                                         .satellite_acquired(satellite_acquired),
                                         .i2q2_ready(i2q2_ready),
                                         .i2q2_tag(i2q2_tag),
                                         .i2q2_value(i2q2_out),
                                         .acquisition_complete(acquisition_complete),
                                         .peak_doppler(acq_peak_doppler),
                                         .peak_code_shift(acq_peak_code_shift),
                                         .peak_i2q2(acq_peak_i2q2));

   //Upsample the C/A code to the incoming sampling rate.
   //Note: All accumulators run on the same code shift.
   wire ca_bit;
   ca_upsampler upsampler(.clk(clk),
                          .reset(reset || start_acq),
                          .mode(`MODE_ACQ),
                          .enable(mem_data_available),
                          //Control interface.
                          .prn(acq_prn),
                          .phase_inc_offset(`CA_PHASE_INC_WIDTH'd0),
                          //C/A code output interface.
                          .out_early(ca_bit),
                          //Seek control.
                          .seek_en(acq_seek_en),
                          .seek_target(acq_seek_target),
                          .target_reached(target_reached));

   //Generate accumulators.
   `KEEP wire acc_complete[0:(`ACQ_NUM_ACCUMULATORS-1)];
   `KEEP wire [`ACC_RANGE] acc_i_out[0:(`ACQ_NUM_ACCUMULATORS-1)], acc_q_out[0:(`ACQ_NUM_ACCUMULATORS-1)];
   `KEEP reg [`ACC_RANGE] acc_i[0:(`ACQ_NUM_ACCUMULATORS-1)], acc_q[0:(`ACQ_NUM_ACCUMULATORS-1)];
   genvar i;
   generate
      for(i=0;i<`ACQ_NUM_ACCUMULATORS;i=i+1) begin : acc_gen
         subchannel acc(.clk(clk),
                        .global_reset(reset),
                        .clear(accumulation_complete),
                        .data_available(mem_data_available),
                        .feed_complete(frame_end),
                        .data(mem_data),
                        .doppler(acq_dopp[i]),
                        .ca_bit(ca_bit),
                        .accumulator_i(acc_i_out[i]),
                        .accumulator_q(acc_q_out[i]),
                        .accumulation_complete(acc_complete[i]));

         //Store accumulation results until I2Q2 calculation
         //has started for each accumulator.
         always @(posedge clk) begin
            acc_i[i] <= accumulation_complete ? acc_i_out[i] : acc_i[i];
            acc_q[i] <= accumulation_complete ? acc_q_out[i] : acc_q[i];
         end
      end // block: acc_gen
   endgenerate
   assign accumulation_complete = acc_complete[0];

   ////////////////////
   // Compute I^2+Q^2
   ////////////////////

   //Square I and Q for each accumulator.
   `KEEP wire start_square;
   reg [`ACQ_ACC_SEL_RANGE] acc_select;
   reg                      acc_i_q_sel;
   assign start_square = !(acc_select==`ACQ_ACC_SEL_MAX && acc_i_q_sel==1'b1);
   
   always @(posedge clk) begin
      acc_select <= reset ? `ACQ_ACC_SEL_MAX :
                    accumulation_complete ? `ACQ_ACC_SEL_WIDTH'd0 :
                    acc_select!=`ACQ_ACC_SEL_MAX && acc_i_q_sel==1'b1 ? acc_select+`ACQ_ACC_SEL_WIDTH'd1 :
                    acc_select;
      
      acc_i_q_sel <= reset ? 1'b0 :
                    accumulation_complete ? 1'b0 :
                    ~acc_i_q_sel;
   end

   //Select next I/Q value.
   //FIXME Preprocessor.
   reg [`ACC_RANGE] i_q_value;
   /*generate
      always @(*) begin
         for(i=0;i<`ACQ_NUM_ACCUMULATORS;i=i+1) begin : i_q_sel
            if(i==0) begin
               if(acc_select==i) begin
                  i_q_value <= acc_i_q_sel ? acc_q[i] : acc_i[i];
               end
            end
            else begin
               else if(acc_select==i) begin
                  i_q_value <= acc_i_q_sel ? acc_q[i] : acc_i[i];
               end
            end
         end // block: i_q_sel
         else begin
            i_q_value <= `ACC_WIDTH'd0;
         end
      end
   endgenerate*/
   always @(*) begin
      i_q_value <= acc_i_q_sel ? acc_q[acc_select] : acc_i[acc_select];
   end
   

   //Take the absolute value of I/Q to
   //reduce multiplier complexity.
   wire [`ACC_MAG_RANGE] mag;
   abs #(.WIDTH(`ACC_WIDTH))
     abs_value(.in(i_q_value),
               .out(mag));

   //Square selected value.
   `KEEP wire [`I2Q2_RANGE] square_result;
   iq_square #(.INPUT_WIDTH(`ACC_MAG_WIDTH),
               .OUTPUT_WIDTH(`I2Q2_WIDTH))
     square(.clock(clk),
            .dataa(mag),
            .result(square_result));

   //Pipe square result for timing.
   `KEEP wire [`I2Q2_RANGE] square_km1;
   delay #(.WIDTH(`I2Q2_WIDTH))
     square_delay(.clk(clk),
                  .reset(reset),
                  .in(square_result),
                  .out(square_km1));

   //Pipe I/Q select value with multiplication in
   //order to clear/sum I2Q2 value.
   `KEEP wire i2_pending;
   delay #(.DELAY(4+1))
     i2_pending_delay(.clk(clk),
                      .reset(reset),
                      .in(acc_i_q_sel==1'b0),
                      .out(i2_pending));

   wire square_ready;
   delay #(.DELAY(4+1))
     square_ready_delay(.clk(clk),
                        .reset(reset),
                        .in(start_square),
                        .out(square_ready));

   //Sum squared values.
   always @(posedge clk) begin
      i2q2_out <= i2_pending ?
                  square_km1 :
                  i2q2_out+square_km1;
      
      i2q2_tag <= reset ? `ACQ_ACC_SEL_MAX :
                  accumulation_complete ? `ACQ_ACC_SEL_WIDTH'd0 :
                  i2q2_ready ? i2q2_tag+`ACQ_ACC_SEL_WIDTH'd1 :
                  i2q2_tag;
   end

   //A new I2Q2 value is ready when the Q2 square completes,
   //and the sum has been added into i2q2_out.
   delay i2q2_ready_delay(.clk(clk),
                          .reset(reset),
                          .in(square_ready && !i2_pending),
                          .out(i2q2_ready));

endmodule