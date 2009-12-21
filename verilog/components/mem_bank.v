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
`include "global.vh"
`include "mem_bank.vh"

`define DEBUG
`include "debug.vh"

module mem_bank (
    input                      clk,
    input                      reset,
    input                      mode,
    input                      data_available,
    input [`INPUT_RANGE]       data_in,

    output wire                ready,
    output wire                frame_start,
    output wire                frame_end,
    output wire                sample_valid,
    output wire [`INPUT_RANGE] data_out
	         );
   
   reg [`ADDRESS_RANGE]      addr;
   reg [`ADDRESS_RANGE]      start_addr;
   
   reg [`SAMPLE_COUNT_RANGE] sample_counter; //wide enough to store # samples in acq time
   
   reg [`OFFSET_RANGE]       offset;
   
   reg [`WORD_RANGE]         buffer;
   
   `KEEP wire [`WORD_RANGE] m4k_out;
   `KEEP wire [`WORD_RANGE] m4k_in;
   
   wire mode_change;
//   wire frame_start_predelay;
//   wire frame_end_predelay;
   
   `KEEP wire m4k_wren;
   mem_bank_ram #(.WORD_LENGTH(`WORD_LENGTH),
                  .NUM_WORDS(`NUM_WORDS),
                  .ADDR_WIDTH(`ADDRESS_LENGTH))
     ram(
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

   reg [`MEM_BANK_WAIT_RANGE] wait_count;
   always @ (posedge clk) begin
      
      if (reset || (mode_change && mode==`MODE_WRITING)) begin
         
         offset <= `OFFSET_LENGTH'd0;
         buffer <= `WORD_LENGTH'h0;
         addr <= `ADDRESS_LENGTH'd0;
         start_addr <= `ADDRESS_LENGTH'd0;
         sample_counter <= `SAMPLE_COUNT_WIDTH'd0;
         wait_count <= `MEM_BANK_WAIT_WIDTH'd0;
         
      end
      
      else if (mode_change) begin
         
         offset <= `BUFFER_MAX_OFFSET_M2;
         buffer <= buffer;
         addr <= (mode == `MODE_PLAYBACK) ? start_addr : `ADDRESS_LENGTH'h0;
         start_addr <= (mode == `MODE_PLAYBACK) ? start_addr : `ADDRESS_LENGTH'h0;
         sample_counter <= (mode == `MODE_PLAYBACK) ? `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M3 : `SAMPLE_COUNT_WIDTH'd0;
         wait_count <= `MEM_BANK_WAIT_WIDTH'd0;
         
      end
      
      else begin

         if (mode == `MODE_PLAYBACK) begin
            if(wait_count!=`MEM_BANK_WAIT_WIDTH'd0) begin
               wait_count <= wait_count==`MEM_BANK_WAIT_MAX ?
                             `MEM_BANK_WAIT_WIDTH'd0 :
                             wait_count+`MEM_BANK_WAIT_WIDTH'd1;
            end
            else begin
               buffer <= (offset == `BUFFER_MAX_OFFSET || sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1) ? m4k_out : 
                         {buffer[`DATA_IN_RANGE],`OFFSET_LENGTH'h0};//FIXME This is 25b and gets truncated to 24b.
               offset <= offset + `OFFSET_LENGTH'd1;
               addr <= (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M3) ? start_addr :
                       (offset != `OFFSET_LENGTH'd1) ? addr :
                       (addr == `ADDRESS_LENGTH'd`NUM_WORDS_M1) ? `ADDRESS_LENGTH'd0 :
                       addr + `ADDRESS_LENGTH'd1 ;

               wait_count <= sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1 ? `MEM_BANK_WAIT_WIDTH'd1 : wait_count;
               
               start_addr <= start_addr;
               sample_counter <= (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1) ? `SAMPLE_COUNT_WIDTH'h0 : sample_counter + `SAMPLE_COUNT_WIDTH'h1;
            end
         end
         
         else begin // mode == `MODE_WRITING
            
            buffer <= data_available ? {buffer[`DATA_IN_RANGE],data_in} : buffer;
            offset <= data_available ? offset + `OFFSET_LENGTH'd1 : offset;
            addr <= !m4k_wren ? addr :
                    (addr == `ADDRESS_LENGTH'd`NUM_WORDS_M1) ? `ADDRESS_LENGTH'd0 :
                    addr + `ADDRESS_LENGTH'd1;
            
            start_addr <= !m4k_wren || (sample_counter != `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1) ? start_addr :
                          start_addr == `ADDRESS_LENGTH'd`NUM_WORDS_M1 ? `ADDRESS_LENGTH'd0 : 
                          start_addr + `ADDRESS_LENGTH'd1;
            
            sample_counter <= !data_available || (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1) ? sample_counter : sample_counter + `SAMPLE_COUNT_WIDTH'h1;
            
         end
      end
   end
   
   strobe #(.FLAG_CHANGE(1))
     mode_change_strobe (
                         .clk(clk),
                         .reset(reset),
                         .in(mode),
                         .out(mode_change));
   
//   delay frame_start_delay (
//                            .clk(clk),
//                            .reset(reset),
//                            .in(frame_start_predelay),
//                            .out(frame_start));
//                            
//   delay frame_end_delay (
//                         .clk(clk),
//                         .reset(reset),
//                         .in(frame_end_predelay),
//                         .out(frame_end));                            
   
   assign ready = (mode == `MODE_WRITING) && (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1) || (mode == `MODE_PLAYBACK);
   assign frame_start = (mode == `MODE_PLAYBACK) &&
                        (sample_counter == `SAMPLE_COUNT_WIDTH'd0) &&
                         wait_count==`MEM_BANK_WAIT_WIDTH'd0;
   assign frame_end = (mode == `MODE_PLAYBACK) && (sample_counter == `SAMPLE_COUNT_WIDTH'd`SAMPLES_PER_ACQ_M1);
   assign sample_valid = (mode == `MODE_PLAYBACK) &&
                         (!mode_change) &&
                         wait_count==`MEM_BANK_WAIT_WIDTH'd0;
   
//   assign frame_start = frame_start_predelay;
//   assign frame_end = frame_end_predelay;
   
endmodule
