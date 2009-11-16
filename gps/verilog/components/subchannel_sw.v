`include "global.vh"

module subchannel_sw(
    input                            clk,
    input                            reset,
    input                            clear,
    //Data and code inputs.
    input                            ca_bit,
    input [(INPUT_WIDTH-1):0]        data_i,
    input [(INPUT_WIDTH-1):0]        data_q,
    //Accumulator states.
    input [(OUTPUT_WIDTH-1):0]       accumulator_i_in,
    input [(OUTPUT_WIDTH-1):0]       accumulator_q_in,
    output wire [(OUTPUT_WIDTH-1):0] accumulator_i_out,
    output wire [(OUTPUT_WIDTH-1):0] accumulator_q_out);
   
   parameter INPUT_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;

   //In-phase accumulator.
   accumulator_sw #(.INPUT_WIDTH(INPUT_WIDTH),
                    .OUTPUT_WIDTH(OUTPUT_WIDTH))
     accumulator_i(.clk(clk),
                   .reset(reset),
                   .clear(clear),
                   .baseband_input(data_i),
                   .ca_bit(ca_bit),
                   .accumulator_in(accumulator_i_in),
                   .accumulator_out(accumulator_i_out));

   //Quadrature accumulator.
   accumulator_sw #(.INPUT_WIDTH(INPUT_WIDTH),
                    .OUTPUT_WIDTH(OUTPUT_WIDTH))
     accumulator_q(.clk(clk),
                   .reset(reset),
                   .clear(clear),
                   .baseband_input(data_q),
                   .ca_bit(ca_bit),
                   .accumulator_in(accumulator_q_in),
                   .accumulator_out(accumulator_q_out));
endmodule