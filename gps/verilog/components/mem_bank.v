`include "global.vh"
`include "mem_bank.vh"

`define DEBUG
`include "debug.vh"

module mem_bank (
	input clk,
	input [`INPUT_RANGE] data_in,
	input data_available,
	input mode,
	input reset,
	
	output wire ready,
	output wire sample_valid,
	output wire frame_start,
	output wire frame_end,
	output wire [`INPUT_RANGE] data_out
	);
	
	reg [`ADDRESS_RANGE] addr;
	reg [`ADDRESS_RANGE] start_addr;
	
	reg [`SAMPLE_COUNT_RANGE] sample_counter; //wide enough to store # samples in acq time
	
	reg [`OFFSET_RANGE] offset;
	
	reg [`WORD_RANGE] buffer;
	
	`KEEP wire [`WORD_RANGE] m4k_out;
	`KEEP wire [`WORD_RANGE] m4k_in;
	
	wire mode_change;
	
	wire m4k_wren;
	
	m4k_ram #(.WORD_LENGTH(`WORD_LENGTH), 
             .NUM_WORDS(`NUM_WORDS),
             .ADDR_WIDTH(`ADDRESS_LENGTH))
       ram (
             .address(addr),
             .clock(clk),
             .data(m4k_in),
             .wren(m4k_wren),
             .q(m4k_out)
	);
	
//	assign data_out = buffer[23:21];
    assign data_out = buffer[`DATA_OUT_RANGE];
	assign m4k_in = buffer;
	
	delay write_enable_flag_delay (
      .clk(clk),
      .reset(reset),
      .in(data_available && (offset == `BUFFER_MAX_OFFSET)),
      .out(m4k_wren));
	
	always @ (posedge clk) begin
   
      if (reset) begin
         
         offset <= `OFFSET_LENGTH'd0;
         buffer <= `WORD_LENGTH'h0;
         addr <= addr;
         start_addr <= start_addr;
         sample_counter <= `SAMPLE_COUNT_WIDTH'd0;
  
      end
      
      else if (mode_change) begin
         
         offset <= `BUFFER_MAX_OFFSET_M2;
         buffer <= buffer;
         addr <= (mode == `MODE_PLAYBACK) ? start_addr : `ADDRESS_LENGTH'h0;
         start_addr <= (mode == `MODE_PLAYBACK) ? start_addr : `ADDRESS_LENGTH'h0;
         sample_counter <= (mode == `MODE_PLAYBACK) ? `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M3 : `SAMPLE_COUNT_WIDTH'd0;
         
      end
      
      else begin
      
         if (mode == `MODE_PLAYBACK) begin
            
            buffer <= (offset == `BUFFER_MAX_OFFSET || sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1) ? m4k_out : 
                           {buffer[`DATA_IN_RANGE],`OFFSET_LENGTH'h0};
            offset <= offset + `OFFSET_LENGTH'd1;
            addr <= (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M4) ? start_addr :
                    (offset != `OFFSET_LENGTH'd1) ? addr :
                    (addr == `ADDRESS_LENGTH'd`NUM_WORDS_M1) ? `ADDRESS_LENGTH'd0 :
                    addr + `ADDRESS_LENGTH'd1 ;
                    
            start_addr <= start_addr;
            sample_counter <= (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1) ? `SAMPLE_COUNT_WIDTH'h0 : sample_counter + `SAMPLE_COUNT_WIDTH'h1;
         end
         
         else begin // mode == `MODE_WRITING

            buffer <= data_available ? {buffer[`DATA_IN_RANGE],data_in} : buffer;
            offset <= data_available ? offset + `OFFSET_LENGTH'd1 : offset;
            addr <= !m4k_wren ? addr :
                    (addr == `ADDRESS_LENGTH'd`NUM_WORDS_M1) ? `ADDRESS_LENGTH'd0 :
                    addr + `ADDRESS_LENGTH'd1;

            start_addr <= !m4k_wren || (sample_counter != `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ) ? start_addr :
                           start_addr == `ADDRESS_LENGTH'd`NUM_WORDS_M1 ? `ADDRESS_LENGTH'd0 : 
                           start_addr + `ADDRESS_LENGTH'd1;
                           
            sample_counter <= !data_available || (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ) ? sample_counter : sample_counter + `SAMPLE_COUNT_WIDTH'h1;

         end
      end
   end
	
	strobe #(.FLAG_CHANGE(1))
      mode_change_strobe (
      .clk(clk),
      .reset(reset),
      .in(mode),
      .out(mode_change));

   assign ready = (mode == `MODE_WRITING) && (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ) || (mode == `MODE_PLAYBACK);
   assign frame_start = (mode == `MODE_PLAYBACK) && (sample_counter == `SAMPLE_COUNT_WIDTH'd0);
   assign frame_end = (mode == `MODE_PLAYBACK) && (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1);
   assign sample_valid = (mode == `MODE_PLAYBACK) && (!mode_change);

endmodule
