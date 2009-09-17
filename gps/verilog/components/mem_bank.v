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
	
	//FIXME add reference to acq_time in mem_bank.csv to do this range
	reg [15:0] sample_counter; //wide enough to store # samples in acq time
	
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
	
	//FIXME parameterize by adding reference to SAMPLE_WIDTH in mem_bank.csv
	assign data_out = buffer[23:21];
	assign m4k_in = buffer;
	
	delay write_enable_flag_delay (
      .clk(clk),
      .reset(reset),
      .in(data_available && (offset == `OFFSET_LENGTH'd7)), //FIXME The value 7 needs to be parameterized
      .out(m4k_wren));
	
	always @ (posedge clk) begin
   
      if (reset) begin
         
         offset <= `OFFSET_LENGTH'd0;
         buffer <= `WORD_LENGTH'h0;
         addr <= addr;
         start_addr <= start_addr;
         sample_counter <= 16'd0; //FIXME parameterize
  
      end
      
      else if (mode_change) begin
         
         offset <= `OFFSET_LENGTH'd5;  //FIXME parameterize 5
         buffer <= buffer;
         addr <= (mode == `MODE_PLAYBACK) ? start_addr : `ADDRESS_LENGTH'h0;
         start_addr <= (mode == `MODE_PLAYBACK) ? start_addr : `ADDRESS_LENGTH'h0;
         sample_counter <= (mode == `MODE_PLAYBACK) ? 16'd50397 : 16'd0; //FIXME: parameterize
         
      end
      
      else begin
      
         if (mode == `MODE_PLAYBACK) begin
            
            buffer <= (offset == `OFFSET_LENGTH'd7) ? m4k_out : {buffer[20:0],`OFFSET_LENGTH'h0}; //FIXME: PARAMETERIZE
            offset <= offset + `OFFSET_LENGTH'd1;
            addr <= (offset != `OFFSET_LENGTH'd1) ? addr :
                    (sample_counter == 16'd50399) ? start_addr : //FIXME
                    (addr == `ADDRESS_LENGTH'd`NUM_WORDS - 1) ? `ADDRESS_LENGTH'd0 :
                    addr + `ADDRESS_LENGTH'd1 ;
                    
            start_addr <= start_addr;
            sample_counter <= (sample_counter == 16'd50399) ? 16'd0 : sample_counter + 16'd1; //FIXME
         end
         
         else begin // mode == `MODE_WRITING

            buffer <= data_available ? {buffer[20:0],data_in} : buffer;  //FIXME
            offset <= data_available ? offset + `OFFSET_LENGTH'd1 : offset;
            addr <= !m4k_wren ? addr :
                    (addr == `ADDRESS_LENGTH'd`NUM_WORDS - 1) ? `ADDRESS_LENGTH'd0 :
                    addr + `ADDRESS_LENGTH'd1;

            start_addr <= data_available && (sample_counter == 16'd50400) ? start_addr + `ADDRESS_LENGTH'd1 : start_addr; //FIXME
            sample_counter <= !data_available || (sample_counter == 16'd50400) ? sample_counter : sample_counter + 16'd1;

         end
      end
   end
	
	strobe #(.FLAG_CHANGE(1))
      mode_change_strobe (
      .clk(clk),
      .reset(reset),
      .in(mode),
      .out(mode_change));

   //FIXME
   assign ready = (mode == `MODE_WRITING) && (sample_counter == 16'd50400) || (mode == `MODE_PLAYBACK);
   assign frame_start = (mode == `MODE_PLAYBACK) && (sample_counter == 16'd0);
   assign frame_end = (mode == `MODE_PLAYBACK) && (sample_counter == 16'd50399);
   assign sample_valid = (mode == `MODE_PLAYBACK) && (!mode_change);

endmodule
