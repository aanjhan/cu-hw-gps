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
module dds(
    input                            clk,
    input                            reset,
    input                            enable,
    input [(PHASE_INC_WIDTH-1):0]    inc,
    output wire [(OUTPUT_WIDTH-1):0] out);
   
   parameter ACC_WIDTH = 1;
   parameter PHASE_INC_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;
   parameter PIPELINE = 0;
   parameter [(ACC_WIDTH-1):0] ACC_RESET_VALUE = {ACC_WIDTH{1'b0}};

   //Increment by zero to implement disable.
   wire [(PHASE_INC_WIDTH-1):0] inc_value;
   //assign inc_value = enable ? inc : {PHASE_INC_WIDTH{1'b0}};
   assign inc_value = inc & {PHASE_INC_WIDTH{enable}};

   //Zero-extend phase increment to accumulator width.
   wire [(ACC_WIDTH-1):0] inc_extended;
   assign inc_extended = {{ACC_WIDTH-PHASE_INC_WIDTH{1'b0}},inc_value};

   wire [(ACC_WIDTH-1):0] next_value;
   generate
      if(PIPELINE) begin
         wire [(ACC_WIDTH-1):0] inc_km1;
         delay #(.WIDTH(ACC_WIDTH))
           next_delay(.clk(clk),
                      .reset(reset),
                      .in(inc_extended),
                      .out(inc_km1));
         assign next_value = accumulator+inc_km1;
      end
      else begin
         assign next_value = accumulator+inc_extended;
      end
   endgenerate

   reg [(ACC_WIDTH-1):0] accumulator;
   always @(posedge clk) begin
      accumulator <= reset ? ACC_RESET_VALUE :
                     next_value;
      //accumulator <= next_value & {ACC_WIDTH{~reset}};
   end

   //Output is the top bits of the phase accumulator.
   assign out = accumulator[(ACC_WIDTH-1):(ACC_WIDTH-OUTPUT_WIDTH)];
endmodule