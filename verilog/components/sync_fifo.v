// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module sync_fifo (
    input                     clk,
    input                     reset,
    output wire               empty,
    output wire               full,
    input                     wr_req,
    input [(WIDTH-1):0]       wr_data,
    input                     rd_req,
    output wire [(WIDTH-1):0] rd_data);

   parameter WIDTH = 1;
   parameter DEPTH = 1;
   
   scfifo scfifo_component(.clock(clk),
			   .sclr(reset),
			   .empty(empty),
			   .full(full),
			   .wrreq(wr_req),
			   .data(wr_data),
			   .rdreq(rd_req),
			   .q(rd_data)
			   // synopsys translate_off
			   ,
			   .aclr (),
			   .almost_empty (),
			   .almost_full (),
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