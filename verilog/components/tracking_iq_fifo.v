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
module tracking_iq_fifo (
    input                     clock,
    input [(WIDTH-1):0]       data,
    input                     rdreq,
    input                     sclr,
    input                     wrreq,
    output wire               empty,
    output wire [(WIDTH-1):0] q);

   parameter WIDTH = 108;
   parameter DEPTH = 4;

   scfifo scfifo_component(.rdreq (rdreq),
			   .sclr (sclr),
			   .clock (clock),
			   .wrreq (wrreq),
			   .data (data),
			   .empty (empty),
			   .q (q)
			   // synopsys translate_off
			   ,
			   .aclr (),
			   .almost_empty (),
			   .almost_full (),
			   .full (),
			   .usedw ()
			   // synopsys translate_on
			   );
   defparam scfifo_component.add_ram_output_register = "OFF",
	    scfifo_component.intended_device_family = "Cyclone II",
	    scfifo_component.lpm_hint = "RAM_BLOCK_TYPE=M4K",
	    scfifo_component.lpm_numwords = DEPTH,
	    scfifo_component.lpm_showahead = "ON",
	    scfifo_component.lpm_type = "scfifo",
	    scfifo_component.lpm_width = WIDTH,
	    scfifo_component.lpm_widthu = 2,
	    scfifo_component.overflow_checking = "ON",
	    scfifo_component.underflow_checking = "ON",
	    scfifo_component.use_eab = "ON";
endmodule
