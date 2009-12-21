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
module dll_divider (
    input                       clock,
    input [DEN_WIDTH-1:0]       denom,
    input [NUM_WIDTH-1:0]       numer,
    output wire [NUM_WIDTH-1:0] quotient,
    output wire [DEN_WIDTH-1:0] remain);

   parameter NUM_WIDTH = 9;
   parameter DEN_WIDTH = 9;

   lpm_divide lpm_divide_component (.denom (denom),
				    .clock (clock),
				    .numer (numer),
				    .quotient (quotient),
				    .remain (remain),
				    .aclr (1'b0),
				    .clken (1'b1));
   defparam lpm_divide_component.lpm_drepresentation = "UNSIGNED",
	    lpm_divide_component.lpm_hint = "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE",
	    lpm_divide_component.lpm_nrepresentation = "UNSIGNED",
	    lpm_divide_component.lpm_pipeline = 2,
	    lpm_divide_component.lpm_type = "LPM_DIVIDE",
	    lpm_divide_component.lpm_widthd = DEN_WIDTH,
	    lpm_divide_component.lpm_widthn = NUM_WIDTH;

endmodule // dll_divider
