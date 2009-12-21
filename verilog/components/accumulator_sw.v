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

module accumulator_sw(
    input                           clk,
    input                           reset,
    input                           clear,
    input [(INPUT_WIDTH-1):0]       baseband_input,
    input                           ca_bit,
    //Accumulator state.
    input [(OUTPUT_WIDTH-1):0]      accumulator_in,
    output reg [(OUTPUT_WIDTH-1):0] accumulator_out);

   parameter INPUT_WIDTH = `INPUT_WIDTH;
   localparam INPUT_SIGN = INPUT_WIDTH-1;
   localparam INPUT_MAG_MSB = INPUT_SIGN-1;
   
   parameter OUTPUT_WIDTH = `INPUT_WIDTH;

   //Wipe off C/A code.
   wire [(INPUT_WIDTH-1):0] wiped_input;
   assign wiped_input[INPUT_SIGN] = baseband_input[INPUT_SIGN]^(~ca_bit);
   assign wiped_input[INPUT_MAG_MSB:0] = baseband_input[INPUT_MAG_MSB:0];

   //Sign-extend value and convert to two's complement.
   wire [(OUTPUT_WIDTH-1):0] input2c;
   ones_extend #(.IN_WIDTH(INPUT_WIDTH),
                 .OUT_WIDTH(OUTPUT_WIDTH))
     input_extend(.value(wiped_input),
                  .result(input2c));

   //Pipe to meet timing.
   wire [(OUTPUT_WIDTH-1):0] input2c_km1;
   delay #(.WIDTH(OUTPUT_WIDTH))
     value_delay(.clk(clk),
                 .reset(reset),
                 .in(input2c),
                 .out(input2c_km1));

   //Accumulate input value.
   always @(*) begin
      accumulator_out <= reset ? {OUTPUT_WIDTH{1'b0}} :
                         clear ? input2c_km1 :
                         accumulator_in+input2c_km1;
   end
endmodule