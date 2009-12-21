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
module mem_bank_ram (
    input                           clock,
    input [(ADDR_WIDTH-1):0]        address,
    input [(WORD_LENGTH-1):0]       data,
    input                           wren,
    output wire [(WORD_LENGTH-1):0] q);
   
   parameter WORD_LENGTH = 24;
   parameter NUM_WORDS   = 8192;
   parameter ADDR_WIDTH  = 13;
   
	
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1	  clock;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

   altsyncram altsyncram_component(.wren_a (wren),
				   .clock0 (clock),
				   .address_a (address),
				   .data_a (data),
				   .q_a (q),
				   .aclr0 (1'b0),
				   .aclr1 (1'b0),
				   .address_b (1'b1),
				   .addressstall_a (1'b0),
				   .addressstall_b (1'b0),
				   .byteena_a (1'b1),
				   .byteena_b (1'b1),
				   .clock1 (1'b1),
				   .clocken0 (1'b1),
				   .clocken1 (1'b1),
				   .clocken2 (1'b1),
				   .clocken3 (1'b1),
				   .data_b (1'b1),
				   .eccstatus (),
				   .q_b (),
				   .rden_a (1'b1),
				   .rden_b (1'b1),
				   .wren_b (1'b0));
   defparam altsyncram_component.clock_enable_input_a = "BYPASS",
	    altsyncram_component.clock_enable_output_a = "BYPASS",
	    altsyncram_component.intended_device_family = "Cyclone II",
	    altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
	    altsyncram_component.lpm_type = "altsyncram",
	    altsyncram_component.numwords_a = NUM_WORDS,
	    altsyncram_component.operation_mode = "SINGLE_PORT",
	    altsyncram_component.outdata_aclr_a = "NONE",
	    altsyncram_component.outdata_reg_a = "CLOCK0",
	    altsyncram_component.power_up_uninitialized = "FALSE",
	    altsyncram_component.ram_block_type = "M4K",
	    altsyncram_component.widthad_a = ADDR_WIDTH,
	    altsyncram_component.width_a = WORD_LENGTH,
	    altsyncram_component.width_byteena_a = 1;
endmodule
