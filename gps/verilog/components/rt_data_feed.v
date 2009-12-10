// This file is part of the Cornell University GPS Hardware Receiver Project.
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

`undef DEBUG
//`define DEBUG
`include "debug.vh"

module rt_data_feed(
    input              clk_50,
    input              reset,
    //DM9000A Ethernet controller interface.
    output wire        enet_clk,
    input              enet_int,
    output wire        enet_rst_n,
    output wire        enet_cs_n,
    output wire        enet_cmd,
    output wire        enet_wr_n,
    output wire        enet_rd_n,
    inout wire [15:0]  enet_data,
    //Sample interface.
    input              clk_sample,
    output wire        sample_valid,
    output wire [2:0]  sample_data,
    //Debug signals.
    output wire        link_status,
    output wire [8:0]  words_available,
    output wire [8:0]  packet_count,
    output wire [8:0]  good_packet_count,
    output wire [8:0]  missed_count,
    //Debug
    output wire [31:0] total_sample_count,
    input              halt_packet);

   //FIXME Add a watchdog to reset packet processor/RX FIFO
   //FIXME if stuck in data state too long. This might happen
   //FIXME if the processor halts the RX FIFO and that then
   //FIXME halts the DM9000A, resulting in data loss.

   /////////////////////////
   // Ethernet Controller
   /////////////////////////

   //DM9000A Ethernet controller module.
   wire        rx_fifo_rd_req;
   wire [15:0] rx_fifo_rd_data;
   wire        rx_fifo_empty;
   dm9000a_controller dm9000a(.clk(clk_50),
                              .reset(reset),
                              .enet_clk(enet_clk),
                              .enet_int(enet_int),
                              .enet_rst_n(enet_rst_n),
                              .enet_cs_n(enet_cs_n),
                              .enet_cmd(enet_cmd),
                              .enet_wr_n(enet_wr_n),
                              .enet_rd_n(enet_rd_n),
                              .enet_data(enet_data),
                              .rx_fifo_rd_clk(enet_clk),
                              .rx_fifo_rd_req(rx_fifo_rd_req),
                              .rx_fifo_rd_data(rx_fifo_rd_data),
                              .rx_fifo_empty(rx_fifo_empty),
                              .halt(1'b0),
                              .link_status(link_status));

   ////////////////////
   // Packet Processor
   ////////////////////

   `KEEP wire        packet_empty;
   `KEEP wire        packet_read;
   `KEEP wire [15:0] packet_data;
   rtdf_packet_processor processor(.reset(reset),
                                   .clk_rx(enet_clk),
                                   .rx_fifo_rd_data(rx_fifo_rd_data),
                                   .rx_fifo_empty(rx_fifo_empty || halt_packet),
                                   .rx_fifo_rd_req(rx_fifo_rd_req),
                                   .clk_read(~clk_sample),
                                   .empty(packet_empty),
                                   .read_next(packet_read),
                                   .data(packet_data),
                                   .words_available(words_available),
                                   .packet_count(packet_count),
                                   .good_packet_count(good_packet_count),
                                   .missed_count(missed_count));

   ////////////////////
   // Sample Generator
   ////////////////////

   sampler data_sampler(.clk_sample(clk_sample),
                        .reset(reset),
                        .packet_empty(packet_empty),
                        .packet_data(packet_data),
                        .packet_read(packet_read),
                        .sample_valid(sample_valid),
                        .sample_data(sample_data),
                        .total_sample_count(total_sample_count));
   
endmodule