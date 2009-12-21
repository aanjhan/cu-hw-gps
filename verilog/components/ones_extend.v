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
module ones_extend(
    input [(IN_WIDTH-1):0]        value,
    output wire [(OUT_WIDTH-1):0] result);
   
   parameter IN_WIDTH = 2;
   parameter OUT_WIDTH = 2;

   //Determine magnitude.
   wire [(IN_WIDTH-2):0] mag;
   assign mag = value[(IN_WIDTH-2):0];

   wire zero;
   assign zero = mag=={IN_WIDTH{1'b0}};

   //Determine input sign.
   wire sign;
   assign sign = zero ? 1'b0 : value[IN_WIDTH-1];

   //Convert input to two's complement.
   wire [(IN_WIDTH-1):0] value2c;
   assign value2c = zero ? {IN_WIDTH{1'b0}} :
                    sign ? -mag :
                    mag;

   //Sign-extend to output.
   assign result[(IN_WIDTH-1):0] = value2c;
   assign result[(OUT_WIDTH-1):(IN_WIDTH)] = {(OUT_WIDTH-IN_WIDTH){sign}};
endmodule