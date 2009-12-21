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
module hex_driver(
    input [3:0]      value,
    input            enable,
    output reg [6:0] display);
    
    always @(value or enable) begin
       if(!enable)display<=7'h7F;
       else begin
        case(value)
        4'h0: display<=7'b1000000;
        4'h1: display<=7'b1111001;
        4'h2: display<=7'b0100100;
        4'h3: display<=7'b0110000;
        4'h4: display<=7'b0011001;
        4'h5: display<=7'b0010010;
        4'h6: display<=7'b0000010;
        4'h7: display<=7'b1111000;
        4'h8: display<=7'b0000000;
        4'h9: display<=7'b0010000;
        4'hA: display<=7'b0001000;
        4'hB: display<=7'b0000011;
        4'hC: display<=7'b1000110;
        4'hD: display<=7'b0100001;
        4'hE: display<=7'b0000110;
        4'hF: display<=7'b0001110;
        endcase // case (value)
       end
    end
endmodule