`include "../components/global.vh"

`define DEBUG
`include "../components/debug.vh"

module top(
    input                      clk,
    input                      global_reset,
    //Sample data.
    input                      clk_sample,
    input                      sample_valid,
    input [`INPUT_RANGE]       data,
    //Memory bank.
    input                      mem_mode,
    output wire                mem_bank_ready,
    output wire                mem_bank_frame_start,
    output wire                mem_bank_frame_end,
    output wire                mem_bank_sample_valid,
    output wire [`INPUT_RANGE] mem_bank_data);

   ///////////////////////////////////
   // Clock Domain Synchronization
   ///////////////////////////////////
   
   //Clock domain crossing usiung a mux recirculation
   //synchronizer, triggered on the sample clock edge.
   `KEEP wire clk_sample_sync;
   synchronizer input_clk_sync(.clk(clk),
                               .in(clk_sample),
                               .out(clk_sample_sync));

   //Data available strobe.
   wire sample_edge;
   strobe data_available_strobe(.clk(clk),
                                .reset(global_reset),
                                .in(clk_sample_sync),
                                .out(sample_edge));

   wire new_sample;
   delay #(.DELAY(2))
     sync_hold_delay(.clk(clk),
                     .reset(global_reset),
                     .in(sample_edge),
                     .out(new_sample));
   
   `PRESERVE reg [`INPUT_RANGE] data_sync;
   `PRESERVE reg data_available;
   always @(posedge clk) begin
      if(new_sample) begin
         data_sync <= data;
         data_available <= sample_valid;
      end
      else begin
         data_available <= 1'b0;
      end
   end

   ///////////////
   // Memory Bank
   ///////////////

   //Memory bank.
   mem_bank bank_0(.clk(clk),
                   .reset(global_reset),
                   .mode(mem_mode),
                   .data_available(data_available),
                   .data_in(data_sync),
                   .ready(mem_bank_ready),
                   .frame_start(mem_bank_frame_start),
                   .frame_end(mem_bank_frame_end),
                   .sample_valid(mem_bank_sample_valid),
                   .data_out(mem_bank_data));
endmodule