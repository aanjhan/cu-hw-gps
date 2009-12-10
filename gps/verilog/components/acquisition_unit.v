module acquisition_unit(
    input                            clk,
    input                            global_reset,
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
    output wire [`DOPPLER_INC_RANGE] acq_peak_doppler,
    output wire [`CS_RANGE]          acq_peak_code_shift);

   //Start the next acquisition as soon as possible.
   wire start_acq;
   assign start_acq = start && !in_progress;

   reg [`PRN_RANGE] acq_prn;
   always @(posedge clk) begin
      acq_prn <= global_reset ? `PRN_WIDTH'd0 :
                 start_acq ? prn :
                 acq_prn;

      in_progress <= global_reset ? 1'b0 :
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
   `KEEP wire                      target_reached;
   reg [`I2Q2_RANGE] i2q2_out;
   reg [`ACQ_ACC_SEL_RANGE] i2q2_tag;
   wire i2q2_ready;
   acquisition_controller acq_controller(.clk(clk),
                                         .global_reset(global_reset),
                                         .start_acquisition(start_acq),
                                         .frame_start(frame_start),
                                         .doppler_0(acq_dopp[0]),
                                         .doppler_1(acq_dopp[1]),
                                         .doppler_2(acq_dopp[2]),
                                         .seek_en(acq_seek_en),
                                         .code_shift(acq_seek_target),
                                         .target_reached(target_reached),
                                         .accumulation_complete(accumulation_complete),
                                         .i2q2_valid(i2q2_valid),
                                         .i2q2_early(i2q2_early),
                                         .i2q2_prompt(i2q2_prompt),
                                         .i2q2_late(i2q2_late),
                                         .acquisition_complete(acquisition_complete),
                                         .peak_doppler(acq_peak_doppler),
                                         .peak_code_shift(acq_peak_code_shift));

   //Upsample the C/A code to the incoming sampling rate.
   //Note: All accumulators run on the same code shift.
   wire ca_bit;
   wire seeking;
   ca_upsampler upsampler(.clk(clk),
                          .reset(global_reset || start_acq),
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
                          .seeking(seeking),
                          .target_reached(target_reached));

   //Generate accumulators.
   `KEEP wire acc_complete[0:(`ACQ_NUM_ACCUMULATORS-1)];
   `KEEP wire [`ACC_RANGE] acc_i_out[0:(`ACQ_NUM_ACCUMULATORS-1)], acc_q_out[0:(`ACQ_NUM_ACCUMULATORS-1)];
   `KEEP reg [`ACC_RANGE] acc_i[0:(`ACQ_NUM_ACCUMULATORS-1)], acc_q[0:(`ACQ_NUM_ACCUMULATORS-1)];
   generate
      genvar i;
      for(i=0;i<`ACQ_NUM_ACCUMULATORS;i=i+1) begin : acc_gen
         subchannel acc(.clk(clk),
                        .global_reset(global_reset),
                        .clear(acc_complete[0]),
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
            acc_i[i] <= acc_complete[i] ? acc_i_out[i] : acc_i[i];
            acc_q[i] <= acc_complete[i] ? acc_q_out[i] : acc_q[i];
         end
      end // block: acc_gen
   endgenerate

   ////////////////////
   // Compute I^2+Q^2
   ////////////////////

   //Square I and Q for each accumulator.
   `KEEP wire start_square;
   reg [`ACQ_ACC_SEL_RANGE] acc_select;
   reg                      acc_i_q_sel;
   assign start_square = !(acc_select==`ACQ_ACC_SEL_MAX && acc_i_q_sel==1'b1);

   //Issue a read to the channel FIFO to discard
   //I/Q values when the last calculation has started.
   assign iq_read = start_square && sub_select==2'h2;
   
   always @(posedge clk) begin
      acc_select <= reset ? `ACQ_ACC_SEL_MAX :
                    acc_complete[0] ? `ACQ_ACC_SEL_WIDTH'd0 :
                    acc_select!=`ACQ_ACC_SEL_MAX && acc_i_q_sel==1'b1 ? acc_select+`ACQ_ACC_SEL_WIDTH'd1 :
                    acc_select;
      
      acc_i_q_sel <= reset ? 1'b0 :
                    acc_complete[0] ? 1'b0 :
                    ~acc_i_q_sel;
   end

   //Select next I/Q value.
   wire [`ACC_RANGE_TRACK] i_q_value;
   always @(*) begin
      generate
         genvar i;
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
            i_q_value <= `ACC_WIDTH_TRACK'd0;
         end
      endgenerate
   end
   

   //Take the absolute value of I/Q to
   //reduce multiplier complexity.
   wire [`ACC_MAG_RANGE] mag;
   abs #(.WIDTH(`ACC_WIDTH_TRACK))
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
                  acc_complete[0] ? `ACQ_ACC_SEL_WIDTH'd0 :
                  square_ready && !i2_pending ? i2q2_tag+`ACQ_ACC_SEL_WIDTH'd1 :
                  i2q2_tag;
   end

   //A new I2Q2 value is ready when the Q2 square completes,
   //and the sum has been added into i2q2_out.
   delay i2q2_ready_delay(.clk(clk),
                          .reset(reset),
                          .in(square_ready && !i2_pending),
                          .out(i2q2_ready));

endmodule