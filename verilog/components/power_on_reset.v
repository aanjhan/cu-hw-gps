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
module power_on_reset(
    input      clk,
    output reg reset);

   parameter WIDTH = 8;

   reg [(WIDTH-1):0] count;
   always @(posedge clk) begin
      count <= count!={WIDTH{1'b1}} ?
               count+{{(WIDTH-1){1'b0}},1'b1} :
               count;

      reset <= count!={WIDTH{1'b1}};
   end
endmodule