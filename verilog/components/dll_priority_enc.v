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
`include "debug.vh"

module dll_priority_enc(
    input             clk,
    input [18:0]      in,
    output wire [4:0] out);

   //The priority encoder is divided into a two-
   //stage pipeline for timing requirements.
   
   //FIXME Parameters with preprocessor or defines.
   
   `PRESERVE reg [12:8] in_km1;
   `PRESERVE reg [4:0] pos;
   always @(posedge clk) begin
      casez(in[18:13])
        6'b1zzzzz: pos <= 5'd18;
        6'b01zzzz: pos <= 5'd17;
        6'b001zzz: pos <= 5'd16;
        6'b0001zz: pos <= 5'd15;
        6'b00001z: pos <= 5'd14;
        6'b000001: pos <= 5'd13;
        default: pos <= 5'd0;
      endcase // casez (in[18:13])

      in_km1 <= in[12:8];
   end // always @ (posedge clk)

   `PRESERVE reg [4:0] pos_km1;
   always @(posedge clk) begin
      if(pos!=5'd0) begin
         pos_km1 <= pos;
      end
      else begin
         casez(in_km1)
           5'b1zzzz: pos_km1 <= 6'd12;
           5'b01zzz: pos_km1 <= 6'd11;
           5'b001zz: pos_km1 <= 6'd10;
           5'b0001z: pos_km1 <= 6'd9;
           5'b00001: pos_km1 <= 6'd8;
           default: pos_km1 <= 6'd7;
      endcase // casez (in_km1)
      end
   end

   assign out = pos_km1;
endmodule