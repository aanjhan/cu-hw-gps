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

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module iq_square (
    input                            clock,
    input [(INPUT_WIDTH-1):0]        dataa,
    output wire [(OUTPUT_WIDTH-1):0] result);

   parameter INPUT_WIDTH = 19;
   parameter OUTPUT_WIDTH = 38;

   altsquare altsquare_component(.clock (clock),
				 .data (dataa),
				 .result (result),
				 .aclr (1'b0),
				 .ena (1'b1));
   defparam altsquare_component.data_width = INPUT_WIDTH,
	    altsquare_component.lpm_type = "ALTSQUARE",
	    altsquare_component.pipeline = 4,
	    altsquare_component.representation = "UNSIGNED",
	    altsquare_component.result_alignment = "MSB",
	    altsquare_component.result_width = OUTPUT_WIDTH;
endmodule
