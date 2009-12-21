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
module rtdf_stream_fifo (
    input              sclr,
    input [15:0]       data,
    input              rdclk,
    input              rdreq,
    input              wrclk,
    input              wrreq,
    output wire [15:0] q,
    output wire        rdempty,
    output wire        wrfull,
    output wire [8:0]  wrusedw);

   parameter DEPTH = 16;

   dcfifo dcfifo_component(.wrclk (wrclk),
			   .rdreq (rdreq),
			   .aclr (sclr),
			   .rdclk (rdclk),
			   .wrreq (wrreq),
			   .data (data),
			   .rdempty (rdempty),
			   .wrusedw (wrusedw),
			   .wrfull (wrfull),
			   .q (q)
			   // synopsys translate_off
			   ,
			   .rdfull (),
			   .rdusedw (),
			   .wrempty ()
			   // synopsys translate_on
			   );
   defparam dcfifo_component.add_usedw_msb_bit = "ON",
	    dcfifo_component.intended_device_family = "Cyclone II",
	    dcfifo_component.lpm_numwords = DEPTH,
	    dcfifo_component.lpm_showahead = "ON",
	    dcfifo_component.lpm_type = "dcfifo",
	    dcfifo_component.lpm_width = 16,
	    dcfifo_component.lpm_widthu = 9,
	    dcfifo_component.overflow_checking = "ON",
	    dcfifo_component.rdsync_delaypipe = 4,
	    dcfifo_component.underflow_checking = "ON",
	    dcfifo_component.use_eab = "ON",
	    dcfifo_component.write_aclr_synch = "ON",
	    dcfifo_component.wrsync_delaypipe = 4;
endmodule
