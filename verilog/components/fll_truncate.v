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
module fll_truncate(
    input [4:0]       index,
    input [18:0]      in,
    output reg [14:0] out);

   //FIXME Parameters with preprocessor or defines.
   parameter INDEX_WIDTH = 1;
   parameter INPUT_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;
   parameter SIGNED = 1;

   //Note: For a signed truncation, the bits returned
   //      are a concatenation of the sign bit and
   //      the OUTPUT_WIDTH bits starting at the index.
   always @(index or in) begin
      case(index)
        5'd17: out <= {in[18],in[17:4]};
        5'd16: out <= {in[18],in[16:3]};
        5'd15: out <= {in[18],in[15:2]};
        5'd14: out <= {in[18],in[14:1]};
        default: out <= {in[18],in[13:0]};
      endcase
   end
endmodule