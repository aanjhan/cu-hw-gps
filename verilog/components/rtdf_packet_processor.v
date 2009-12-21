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
`include "rtdf_packet_processor.vh"

`undef DEBUG
//`define DEBUG
`include "debug.vh"

module rtdf_packet_processor(
    input              reset,
    //Ethernet data interface.
    input              clk_rx,
    input [15:0]       rx_fifo_rd_data,
    input              rx_fifo_empty,
    output wire        rx_fifo_rd_req,
    //Packet data interface.
    input wire         clk_read,
    input wire         read_next,
    output wire        empty,
    output wire [15:0] data,
    //Debug
    output reg [8:0]   packet_count,
    output reg [8:0]   good_packet_count,
    output reg [8:0]   missed_count,
    output wire [8:0]  words_available);

   //Post-packet processing stream data FIFO.
   `KEEP wire        fifo_full;
   `PRESERVE reg         fifo_wr_req;
   `PRESERVE reg [15:0]  fifo_wr_data;
   rtdf_stream_fifo #(.DEPTH(`RTDF_FIFO_DEPTH))
     stream_fifo(.sclr(reset),
                 .wrclk(clk_rx),
                 .wrreq(fifo_wr_req),
                 .data(fifo_wr_data),
                 .rdclk(clk_read),
                 .rdreq(read_next),
                 .q(data),
                 .rdempty(empty),
                 .wrfull(fifo_full),
                 .wrusedw(words_available));

   //Packet processing state machine.
   `PRESERVE reg [`RTDF_PKT_LENGTH_RANGE] packet_length;
   `PRESERVE reg [`RTDF_STATE_RANGE]      packet_state;
   `PRESERVE reg                          ignore_packet;
   reg [15:0]          next_seq;
   reg                 need_seq;
   always @(posedge clk_rx) begin
      if(reset) begin
         packet_state <= `RTDF_STATE_LENGTH;
         packet_length <= `RTDF_PKT_LENGTH_WIDTH'd0;
         ignore_packet <= 1'b0;
         fifo_wr_req <= 1'b0;

         packet_count <= 9'd0;
         good_packet_count <= 9'd0;

         next_seq <= 16'd1;
         missed_count <= 9'd0;
      end
      else if(rx_fifo_empty) begin
         packet_state <= packet_state;
         packet_length <= packet_length;
         ignore_packet <= ignore_packet;
         fifo_wr_req <= 1'b0;
      end
      else begin
         case(packet_state)
           //Wait for a packet to become available and
           //store packet length, less the source and
           //destination MAC addresses, EtherType, and
           //CRC if enabled.
           `RTDF_STATE_LENGTH: begin
              packet_state <= `RTDF_STATE_DEST_0;
              
              fifo_wr_req <= 1'b0;

              packet_length <= rx_fifo_rd_data[`RTDF_PKT_LENGTH_RANGE]-`RTDF_PKT_OH_LENGTH;
           end
           //Ignore destination address.
           `RTDF_STATE_DEST_0: begin
              packet_state <= `RTDF_STATE_DEST_1;

              packet_count <= packet_count+9'd1;
           end
           `RTDF_STATE_DEST_1: begin
              packet_state <= `RTDF_STATE_DEST_2;
           end
           `RTDF_STATE_DEST_2: begin
              packet_state <= `RTDF_STATE_SOURCE_0;
           end
           //Ignore source address.
           `RTDF_STATE_SOURCE_0: begin
              packet_state <= `RTDF_STATE_SOURCE_1;
           end
           `RTDF_STATE_SOURCE_1: begin
              packet_state <= `RTDF_STATE_SOURCE_2;
           end
           `RTDF_STATE_SOURCE_2: begin
              packet_state <= `RTDF_STATE_ETHERTYPE;
           end
           //Check EtherType and discard packet if
           //it is an unsupported type.
           `RTDF_STATE_ETHERTYPE: begin
              packet_state <= `RTDF_STATE_DATA;

              //Note: network byte-order is big endian,
              //however the Ethernet interface records
              //in bytes with no knowledge of field sizes.
              ignore_packet <= {rx_fifo_rd_data[7:0],rx_fifo_rd_data[15:8]}!=`RTDF_ETHERTYPE;

              good_packet_count <= {rx_fifo_rd_data[7:0],rx_fifo_rd_data[15:8]}!=`RTDF_ETHERTYPE ?
                                   good_packet_count :
                                   good_packet_count+9'd1;

              need_seq <= 1'b1;
           end
           //Read packet data. If CRC is enabled, go to
           //CRC discard state when packet completes.
           `RTDF_STATE_DATA: begin
              packet_state <= fifo_full ? `RTDF_STATE_DATA :
                              packet_length>`RTDF_PKT_LENGTH_WIDTH'd2 ? `RTDF_STATE_DATA :
                              `RTDF_CRC_ENABLE ? `RTDF_STATE_CRC :
                              `RTDF_STATE_LENGTH;
              
              fifo_wr_req <= !need_seq &&
                             !ignore_packet && !fifo_full;
              fifo_wr_data <= rx_fifo_rd_data;

              need_seq <= 1'b0;
              missed_count <= !need_seq || ignore_packet ? missed_count :
                              {rx_fifo_rd_data[7:0],rx_fifo_rd_data[15:8]}!=next_seq ? missed_count+9'd1 :
                              missed_count;
              next_seq <= need_seq && !ignore_packet ? {rx_fifo_rd_data[7:0],rx_fifo_rd_data[15:8]}+16'd1 : next_seq;

              packet_length <= fifo_full ? packet_length :
                               packet_length==`RTDF_PKT_LENGTH_WIDTH'd1 ? `RTDF_PKT_LENGTH_WIDTH'd0 :
                               packet_length-`RTDF_PKT_LENGTH_WIDTH'd2;
           end
           //Discard 4 Ethernet CRC bytes.
           `RTDF_STATE_CRC: begin
              packet_state <= packet_length==`RTDF_PKT_LENGTH_WIDTH'd0 ?
                              `RTDF_STATE_LENGTH :
                              `RTDF_STATE_CRC;
              
              fifo_wr_req <= 1'b0;

              packet_length <= packet_length+`RTDF_PKT_LENGTH_WIDTH'd1;
           end
         endcase
      end
   end // always @ (posedge clk)

   //Assert a read request to the RX FIFO
   //as soon as data is available.
   assign rx_fifo_rd_req = !fifo_full && !rx_fifo_empty;

endmodule