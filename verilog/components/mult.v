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
module mult(
    input [2:0] carrier,
    input [2:0] signal,
    output reg [4:0] out);

   always @(carrier or signal) begin
      casez({carrier[1:0],signal[1:0]})
        4'b0101: out[3:0]<=4'd1;//1*1
        4'b0110: out[3:0]<=4'd2;//1*2
        4'b0111: out[3:0]<=4'd3;//1*3
        4'b1001: out[3:0]<=4'd2;//2*1
        4'b1010: out[3:0]<=4'd4;//2*2
        4'b1011: out[3:0]<=4'd6;//2*3
        4'b1101: out[3:0]<=4'd3;//3*1
        4'b1110: out[3:0]<=4'd6;//3*2
        4'b1111: out[3:0]<=4'd9;//3*3
        default: out[3:0]<=4'h0;
      endcase // casez ({carrier,signal})

      out[4] <= carrier[1:0]==2'h0 ? 1'b0 :
                signal[1:0]==2'h0 ? 1'b0 :
                carrier[2]^signal[2];
   end
   
endmodule