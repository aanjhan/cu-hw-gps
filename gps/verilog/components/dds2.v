module dds2(
    input                            clk,
    input                            reset,
    input                            enable,
    input [(PHASE_INC_WIDTH-1):0]    inc,
    output wire [(OUTPUT_WIDTH-1):0] out);
   
   parameter ACC_WIDTH = 1;
   parameter PHASE_INC_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;

   wire [(ACC_WIDTH-1):0] accumulator;
   wire [(PHASE_INC_WIDTH-1):0] inc_value;
   assign inc_value = enable ? inc : {PHASE_INC_WIDTH{1'b0}};

   altaccumulate accumulator_func(.clock(clk),
			          .aclr(reset),
			          .data(inc_value),
			          .result(accumulator)
			          // synopsys translate_off
			          ,
			          .add_sub (),
			          .cin (),
			          .clken (),
			          .cout (),
			          .overflow (),
			          .sign_data (),
			          .sload ()
			          // synopsys translate_on
			          );
   defparam accumulator_func.lpm_representation = "UNSIGNED",
	    accumulator_func.lpm_type = "altaccumulate",
	    accumulator_func.width_in = PHASE_INC_WIDTH,
	    accumulator_func.width_out = ACC_WIDTH;

   //Output is the top bits of the phase accumulator.
   assign out = accumulator[(ACC_WIDTH-1):(ACC_WIDTH-OUTPUT_WIDTH)];
endmodule