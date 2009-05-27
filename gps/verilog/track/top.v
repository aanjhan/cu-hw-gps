`include "../components/global.vh"

module top(
    input                    clk,
    input                    global_reset,
    input                    reset,
    //Sample data.
    input                    clk_sample,
    input [`INPUT_RANGE]     data,
    //Carrier control.
    input [1:0]              doppler,//FIXME range?
    //Code control.
    input [4:0]              prn,
    input                    seek_en,
    input [`CS_RANGE]        seek_target,
    output wire [`CS_RANGE]  code_shift,
    //Outputs.
    output wire [`ACC_RANGE] accumulator,
    //Debug outputs.
    output wire              ca_bit,
    output wire              ca_clk,
    output wire [9:0]        ca_code_shift);

   //Clock domain crossing.
   wire clk_sample_sync;
   synchronizer input_clk_sync(.clk(clk),
                               .in(clk_sample),
                               .out(clk_sample_sync));
   
   wire [`INPUT_RANGE] data_sync;
   synchronizer #(.WIDTH(`INPUT_WIDTH))
     input_data_sync(.clk(clk),
                     .in(data),
                     .out(data_sync));

   //Data available strobe.
   wire data_available;
   strobe data_available_strobe(.clk(clk),
                                .reset(reset),
                                .in(clk_sample_sync),
                                .out(data_available));

   //Prompt subchannel.
   subchannel prompt(.clk(clk),
                     .global_reset(global_reset),
                     .reset(reset),
                     .data_available(data_available),
                     .data(data_sync),
                     .doppler(2'h0),
                     .prn(prn),
                     .seek_en(seek_en),
                     .seek_target(seek_target),
                     .code_shift(code_shift),
                     .accumulator(accumulator),
                     .ca_bit(ca_bit),
                     .ca_clk(ca_clk),
                     .ca_code_shift(ca_code_shift));
endmodule