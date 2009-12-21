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
module dll_multiplier (
    input                          clock,
    input [INPUT_A_WIDTH-1:0]      dataa,
    input [INPUT_B_WIDTH-1:0]      datab,
    output wire [OUTPUT_WIDTH-1:0] result);

   parameter INPUT_A_WIDTH = 9;
   parameter INPUT_B_WIDTH = 9;
   localparam OUTPUT_WIDTH = INPUT_A_WIDTH+INPUT_B_WIDTH;

   lpm_mult lpm_mult_component (.dataa (dataa),
				.datab (datab),
				.clock (clock),
				.result (result),
				.aclr (1'b0),
				.clken (1'b1),
				.sum (1'b0));
   defparam lpm_mult_component.lpm_hint = "MAXIMIZE_SPEED=9",
	    lpm_mult_component.lpm_pipeline = 1,
	    lpm_mult_component.lpm_representation = "UNSIGNED",
	    lpm_mult_component.lpm_type = "LPM_MULT",
	    lpm_mult_component.lpm_widtha = INPUT_A_WIDTH,
	    lpm_mult_component.lpm_widthb = INPUT_B_WIDTH,
	    lpm_mult_component.lpm_widthp = OUTPUT_WIDTH;

endmodule
