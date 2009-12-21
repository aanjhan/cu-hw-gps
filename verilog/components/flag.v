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
module flag(
    input       clk,
    input       reset,
    input       clear,
    input       set,
    output wire out);

   parameter RESET_SET = 0;

   reg pending;
   always @(posedge clk) begin
      pending <= reset ? (RESET_SET ? 1'b1 : 1'b0) :
                 clear ? 1'b0 :
                 set ? 1'b1 :
                 pending;
   end

   assign out = set || pending;
   
endmodule