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
module channel_slot_mem (
    input                          clock,
    input                          aclr,
    input [(DATA_WIDTH-1):0]       data,
    input [(ADDR_WIDTH-1):0]       rdaddress,
    input [(ADDR_WIDTH-1):0]       wraddress,
    input                          wren,
    output wire [(DATA_WIDTH-1):0] q);

   parameter DEPTH;
   parameter ADDR_WIDTH;
   parameter DATA_WIDTH;

   altsyncram	altsyncram_component (.wren_a (wren),
				      .aclr0 (aclr),
				      .clock0 (clock),
				      .address_a (wraddress),
				      .address_b (rdaddress),
				      .data_a (data),
				      .q_b (q),
				      .aclr1 (1'b0),
				      .addressstall_a (1'b0),
				      .addressstall_b (1'b0),
				      .byteena_a (1'b1),
				      .byteena_b (1'b1),
				      .clock1 (1'b1),
				      .clocken0 (1'b1),
				      .clocken1 (1'b1),
				      .clocken2 (1'b1),
				      .clocken3 (1'b1),
				      .data_b ({DATA_WIDTH{1'b1}}),
				      .eccstatus (),
				      .q_a (),
				      .rden_a (1'b1),
				      .rden_b (1'b1),
				      .wren_b (1'b0));
   defparam altsyncram_component.address_reg_b = "CLOCK0",
	    altsyncram_component.clock_enable_input_a = "BYPASS",
	    altsyncram_component.clock_enable_input_b = "BYPASS",
	    altsyncram_component.clock_enable_output_a = "BYPASS",
	    altsyncram_component.clock_enable_output_b = "BYPASS",
	    altsyncram_component.intended_device_family = "Cyclone II",
	    altsyncram_component.lpm_type = "altsyncram",
	    altsyncram_component.numwords_a = DEPTH,
	    altsyncram_component.numwords_b = DEPTH,
	    altsyncram_component.operation_mode = "DUAL_PORT",
	    altsyncram_component.outdata_aclr_b = "CLEAR0",
	    altsyncram_component.outdata_reg_b = "CLOCK0",
	    altsyncram_component.power_up_uninitialized = "FALSE",
	    altsyncram_component.read_during_write_mode_mixed_ports = "OLD_DATA",
	    altsyncram_component.widthad_a = ADDR_WIDTH,
	    altsyncram_component.widthad_b = ADDR_WIDTH,
	    altsyncram_component.width_a = DATA_WIDTH,
	    altsyncram_component.width_b = DATA_WIDTH,
	    altsyncram_component.width_byteena_a = 1;
endmodule