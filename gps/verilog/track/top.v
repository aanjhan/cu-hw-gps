`include "../components/global.vh"
`include "../components/subchannel.vh"

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
   wire clk_sample_sync /* synthesis keep */;
   synchronizer input_clk_sync(.clk(clk),
                               .in(clk_sample),
                               .out(clk_sample_sync));
   
   wire reset_sync /* synthesis keep */;
   synchronizer input_reset_sync(.clk(clk),
                                 .in(reset),
                                 .out(reset_sync));
   
   wire [`INPUT_RANGE] data_sync /* synthesis keep */;
   synchronizer #(.WIDTH(`INPUT_WIDTH))
     input_data_sync(.clk(clk),
                     .in(data),
                     .out(data_sync));

   //Data available strobe.
   wire data_available /* synthesis keep */;
   strobe data_available_strobe(.clk(clk),
                                .reset(reset_sync),
                                .in(clk_sample_sync),
                                .out(data_available));

   //Prompt subchannel.
   wire [`ACC_RANGE] accumulator_q;
   subchannel prompt(.clk(clk),
                     .global_reset(global_reset),
                     .reset(reset_sync),
                     .data_available(data_available),
                     .data(data_sync),
                     .doppler({`DOPPLER_INC_WIDTH{1'b0}}),
                     .prn(prn),
                     .seek_en(seek_en),
                     .seek_target(seek_target),
                     .code_shift(code_shift),
                     .accumulator_i(accumulator),
                     .accumulator_q(accumulator_q),
                     .ca_bit(ca_bit),
                     .ca_clk(ca_clk),
                     .ca_code_shift(ca_code_shift));
endmodule