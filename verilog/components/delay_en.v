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
module delay_en(
    input                     clk,
    input                     reset,
    input                     enable,
    input [(WIDTH-1):0]       in,
    output wire [(WIDTH-1):0] out);

   parameter WIDTH = 1;
   parameter DELAY = 1;

   wire [(WIDTH-1):0] in_km[0:DELAY];

   assign in_km[0] = in;

   genvar i;
   generate
      for(i=1;i<=DELAY;i=i+1) begin:delay_gen
         delay_en_1 #(.WIDTH(WIDTH))
           d(.clk(clk),
             .reset(reset),
             .enable(enable),
             .in(in_km[i-1]),
             .out(in_km[i]));
      end
   endgenerate

   assign out = in_km[DELAY];
   
endmodule