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
module synchronizer(
    input                     clk,
    input [(WIDTH-1):0]       in,
    output wire [(WIDTH-1):0] out);

   parameter WIDTH = 1;

   reg [(WIDTH-1):0] sync[1:2];
   always @(posedge clk) begin
      sync[1] <= in;
      sync[2] <= sync[1];
   end

   assign out = sync[2];
   
endmodule