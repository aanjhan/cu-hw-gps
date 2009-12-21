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