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
module strobe_sw(
    input       clk,
    input       reset,
    input       in,
    output wire out,
    //Strobe state.
    input       hist_in,
    output reg  hist_out);

   parameter STROBE_AFTER_RESET = 0;
   parameter RESET_ZERO = 0;
   parameter RESET_ONE = 0;
   parameter FLAG_CHANGE = 0;
   
   always @(*) begin
      if(STROBE_AFTER_RESET)hist_out <= reset ? ~in : in;
      else if(RESET_ZERO)hist_out <= reset ? 1'b0 : in;
      else if(RESET_ONE)hist_out <= reset ? 1'b1 : in;
      else hist_out <= in;
   end
   
   assign out = reset ? 1'b0 :
                FLAG_CHANGE ? in!=hist_in :
                (in & ~hist_in);

endmodule
