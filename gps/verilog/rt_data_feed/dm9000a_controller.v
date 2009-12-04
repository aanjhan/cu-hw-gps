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

`include "dm9000a_controller.vh"

`undef DEBUG
//`define DEBUG
`include "../components/debug.vh"

module dm9000a_controller(
    input              clk,
    input              reset,
    //DM9000A Ethernet controller interface.
    output wire        enet_clk,
    input              enet_int,
    output wire        enet_rst_n,
    output wire        enet_cs_n,
    output reg         enet_cmd,
    output reg         enet_wr_n,
    output reg         enet_rd_n,
    inout wire [15:0]  enet_data,
    //RX data FIFO interface.
    input              rx_fifo_rd_clk,
    input              rx_fifo_rd_req,
    output wire [15:0] rx_fifo_rd_data,
    output wire        rx_fifo_empty,
    //TX data FIFO interface.
    input              tx_fifo_wr_clk,
    input              tx_fifo_wr_req,
    output wire [15:0] tx_fifo_wr_data,
    output wire        tx_fifo_full,
    //Control and status.
    input              halt,
    output reg         link_status);

   parameter MAC_ADDRESS = 48'h010203040506;
   parameter MULTICAST_ADDRESS = 64'h0;
   parameter PROMISCUOUS_EN = 1'b1;
   parameter BROADCAST_EN = 1'b1;

   //Generate 25MHz control clock from 50MHz reference.
   wire clk_enet;
   dm9000a_clk_gen clk_gen(.clk(clk),
                           .clk_enet(clk_enet));

   //Ethernet control signals.
   assign enet_clk = clk_enet;
   assign enet_rst_n = ~reset;
   assign enet_cs_n = 1'b0;

   //Ethernet data RX FIFO.
   wire        rx_fifo_full;
   reg         rx_fifo_wr_req;
   reg [15:0]  rx_fifo_wr_data;
   rx_data_fifo #(.DEPTH(`DM9000A_RX_FIFO_DEPTH))
     rx_fifo(.sclr(reset),
             .wrclk(clk_enet),
             .data(rx_fifo_wr_data),
             .wrreq(rx_fifo_wr_req),
             .wrfull(rx_fifo_full),
             .rdclk(rx_fifo_rd_clk),
             .rdreq(rx_fifo_rd_req),
             .q(rx_fifo_rd_data),
             .rdempty(rx_fifo_empty));

   //Ethernet data TX FIFO.
   wire        tx_fifo_empty;
   reg         tx_fifo_rd_req;
   reg [15:0]  tx_fifo_rd_data;
   rx_data_fifo #(.DEPTH(`DM9000A_TX_FIFO_DEPTH))
     tx_fifo(.sclr(reset),
             .wrclk(tx_fifo_wr_clk),
             .data(tx_fifo_wr_data),
             .wrreq(tx_fifo_wr_req),
             .wrfull(tx_fifo_full),
             .rdclk(clk_enet),
             .rdreq(tx_fifo_rd_req),
             .q(tx_fifo_rd_data),
             .rdempty(tx_fifo_empty));

   //A FIFO halt occurs when the FIFO is full
   //and cannot accept new data, or when halted
   //by the upper level.
   wire fifo_halt;
   assign fifo_halt = rx_fifo_full || halt;

   //The following signals setup a command issue from
   //the initialization state machine to the control.
   wire       issue_ready;
   reg        issue_read;
   reg [15:0] issue_register;
   reg [15:0] issue_data;
   
   //Received packet information.
   reg [15:0] rx_length;
   reg        rx_bad_packet;
   reg        rx_odd_length;

   //Transmitted packet information.
   //Note: The maximum packet length should be the
   //      Ethernet MTU size (1500 B).
   reg [10:0] tx_length;
   wire       tx_start;
   wire       tx_finish;
   reg        tx_in_progress;

   always @(posedge clk_enet) begin
      tx_in_progress <= reset ? 1'b0 :
                        tx_start ? 1'b1 :
                        tx_finish ? 1'b0 :
                        tx_in_progress;
   end

   assign tx_start = state==`DM9000A_STATE_TX_START;

   //Packet RX ix halted whenever a FIFO halt is
   //asserted and the packet is valid. If the packet
   //is bad, it is not placed in the FIFO and is
   //discarded regardless of the halt condition.
   wire rx_halt;
   assign rx_halt = fifo_halt && !rx_bad_packet;

   //Enable address cycling, and link change and RX interrupts.
   localparam INTERRUPT_FLAGS = (`DM9000A_BIT_IMR_PAR |
                                 `DM9000A_BIT_IMR_LNKCHGI |
                                 `DM9000A_BIT_IMR_PTI |
                                 `DM9000A_BIT_IMR_PRI);

   //A packet is bad if any of the following flags are set.
   localparam BAD_PACKET_FLAGS = (`DM9000A_BIT_RXSR_RF |
                                  `DM9000A_BIT_RXSR_LCS |
                                  `DM9000A_BIT_RXSR_RWTO |
                                  `DM9000A_BIT_RXSR_PLE |
                                  `DM9000A_BIT_RXSR_AE |
                                  `DM9000A_BIT_RXSR_CE |
                                  `DM9000A_BIT_RXSR_FOE);

   //The DM9000A asserts enet_int after a software
   //reset until ready (undocumented). Disable all
   //interrupts until the interrupt signal is deasserted
   //after a reset.
   reg enet_int_en;
   reg enet_int_km1;
   always @(posedge clk_enet) begin
      enet_int_en <= reset ? 1'b0 :
                   enet_int_km1 && !enet_int ? 1'b1 :
                   enet_int_en;
      enet_int_km1 <= enet_int;
   end
   
   //DM9000A control state machine - used to issue
   //a single command and send/receive subsequent data.
   //Also used to transmit/receive packet data.
   `PRESERVE reg [`DM9000A_STATE_RANGE] state;
   reg                          initializing;
   reg [15:0]                   data_out;
   always @(posedge clk_enet) begin
      if(reset) begin
         data_out <= data_out;
         state <= `DM9000A_STATE_IDLE;

         rx_fifo_wr_req <= 1'b0;
         rx_bad_packet <= 1'b0;

         tx_length <= 11'd0;

         enet_cmd <= `DM9000A_TYPE_DATA;
         enet_wr_n <= 1'b1;
         enet_rd_n <= 1'b1;
      end
      else begin
         case(state)
           `DM9000A_STATE_IDLE: begin
              state <= issue_ready ? `DM9000A_STATE_SETUP :
                       !tx_fifo_empty && !tx_in_progress ? `DM9000A_STATE_TX_LENL_SETUP :
                       `DM9000A_STATE_IDLE;
              
              rx_fifo_wr_req <= 1'b0;

              //Store data if a read just occurred.
              data_out <= ~enet_rd_n ? enet_data : data_out;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end

           ///////////////////////////////////
           // Register Read/Write Sequence
           ///////////////////////////////////
           
           //Note: RX prefetches require two reads to
           //      obtain a status word. Additionally,
           //      the DM9000A requires 80ns delay
           //      between the two reads.
           
           //Setup register index and command type.
           `DM9000A_STATE_SETUP: begin
              data_out <= issue_register;
              state <= issue_register==`DM9000A_REG_MEM_RD_INC ?
                       `DM9000A_STATE_RX_SETUP_SPIN :
                       `DM9000A_STATE_SETUP_SPIN;

              enet_cmd <= `DM9000A_TYPE_INDEX;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Deassert enable lines for one cycle to meet
           //DM9000A timing specs.
           `DM9000A_STATE_SETUP_SPIN: begin
              state <= issue_read ?
                       `DM9000A_STATE_READ :
                       `DM9000A_STATE_WRITE;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Read data register. If reading for a prefetch
           //spin and read again.
           `DM9000A_STATE_READ: begin
              data_out <= data_out;
              state <= issue_register==`DM9000A_REG_MEM_RD_PF ?
                       `DM9000A_STATE_READ_PF_SPIN_0 :
                       `DM9000A_STATE_IDLE;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b0;
           end
           //Write to data register.
           `DM9000A_STATE_WRITE: begin
              data_out <= issue_data;
              state <= `DM9000A_STATE_IDLE;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //First spin cycle before re-reading prefetch result.
           `DM9000A_STATE_READ_PF_SPIN_0: begin
              state <= `DM9000A_STATE_READ_PF_SPIN_1;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Second spin cycle before re-reading prefetch result.
           `DM9000A_STATE_READ_PF_SPIN_1: begin
              state <= `DM9000A_STATE_READ_PF;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Read prefetch result (status word).
           `DM9000A_STATE_READ_PF: begin
              state <= `DM9000A_STATE_IDLE;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b0;
           end

           /////////////////////////
           // Packet TX Sequence
           /////////////////////////

           //Transmit packet data.
           //Complete TX sequence:
           //  --Setup TX length low register (1 cycle).
           //  --Spin (1 cycle).
           //  --Write TX length low byte (1 cycle).
           //  --Spin (1 cycle).
           //  --Setup TX length high register (1 cycle).
           //  --Spin (1 cycle).
           //  --Write TX length high byte (1 cycle).
           //  --Spin (1 cycle).
           //  --Setup TX register (1 cycle).
           //  --Spin (1 cycle).
           //  --Send destination address (3 cycles + 3 spin cycles).
           //  --Send source address (3 cycles + 3 spin cycles).
           //  --Send EtherType (1 cycle + 1 spin cycle).
           //  --Send frame data (length/2 cycles + length/2 spin cycles).
           //  --Setup TX control register (1 cycle).
           //  --Spin (1 cycle).
           //  --Assert TX request bit to start transmission (1 cycle).
           //Total time: 27+length cycles.
           
           //Setup TX low register.
           //Read TX length from FIFO.
           `DM9000A_STATE_TX_LENL_SETUP: begin
              data_out <= `DM9000A_REG_TX_LEN_L;
              state <= `DM9000A_STATE_TX_LENL_SETUP_SPIN;

              tx_length <= tx_fifo_rd_data;
              tx_fifo_rd_req <= 1'b1;

              enet_cmd <= `DM9000A_TYPE_INDEX;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after TX low setup.
           `DM9000A_STATE_TX_LENL_SETUP_SPIN: begin
              state <= `DM9000A_STATE_TX_LENL;
              
              tx_fifo_rd_req <= 1'b0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Send TX low byte.
           `DM9000A_STATE_TX_LENL: begin
              data_out <= {8'h0,tx_length[7:0]};
              state <= `DM9000A_STATE_TX_LENL_SPIN;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after TX low byte.
           `DM9000A_STATE_TX_LENL_SPIN: begin
              state <= `DM9000A_STATE_TX_LENH_SETUP;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Setup TX high register.
           `DM9000A_STATE_TX_LENH_SETUP: begin
              data_out <= `DM9000A_REG_TX_LEN_H;
              state <= `DM9000A_STATE_TX_LENH_SETUP_SPIN;

              enet_cmd <= `DM9000A_TYPE_INDEX;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after TX high setup.
           `DM9000A_STATE_TX_LENH_SETUP_SPIN: begin
              state <= `DM9000A_STATE_TX_LENH;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Send TX high byte.
           `DM9000A_STATE_TX_LENH: begin
              data_out <= {13'h0,tx_length[10:8]};
              state <= `DM9000A_STATE_TX_LENH_SPIN;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after TX high byte.
           `DM9000A_STATE_TX_LENH_SPIN: begin
              state <= `DM9000A_STATE_TX_DATA_SETUP;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Setup data transmission.
           `DM9000A_STATE_TX_DATA_SETUP: begin
              data_out <= `DM9000A_REG_TX_MEM_WR_INC;
              state <= `DM9000A_STATE_TX_DATA_SETUP_SPIN;

              enet_cmd <= `DM9000A_TYPE_INDEX;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after TX setup.
           `DM9000A_STATE_TX_DATA_SETUP_SPIN: begin
              state <= `DM9000A_STATE_TX_DEST_0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Transmit destination address (cycle 1).
           `DM9000A_STATE_TX_DEST_0: begin
              data_out <= {tx_fifo_rd_data[39:32],tx_fifo_rd_data[47:40]};
              state <= !tx_fifo_empty ?
                       `DM9000A_STATE_TX_DEST_SPIN_0 :
                       `DM9000A_STATE_TX_DEST_0;

              tx_fifo_rd_req <= !tx_fifo_empty;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= !tx_fifo_empty;
              enet_rd_n <= 1'b1;
           end
           //Spin after destination address (cycle 1).
           `DM9000A_STATE_TX_DEST_SPIN_0: begin
              state <= `DM9000A_STATE_TX_DEST_1;
              
              tx_fifo_rd_req <= 1'b0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Transmit destination address (cycle 2).
           `DM9000A_STATE_TX_DEST_1: begin
              data_out <= {tx_fifo_rd_data[23:16],tx_fifo_rd_data[31:24]};
              state <= !tx_fifo_empty ?
                       `DM9000A_STATE_TX_DEST_SPIN_1 :
                       `DM9000A_STATE_TX_DEST_1;

              tx_fifo_rd_req <= !tx_fifo_empty;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= !tx_fifo_empty;
              enet_rd_n <= 1'b1;
           end
           //Spin after destination address (cycle 2).
           `DM9000A_STATE_TX_DEST_SPIN_1: begin
              state <= `DM9000A_STATE_TX_DEST_2;
              
              tx_fifo_rd_req <= 1'b0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Transmit destination address (cycle 3).
           `DM9000A_STATE_TX_DEST_2: begin
              data_out <= {tx_fifo_rd_data[7:0],tx_fifo_rd_data[15:8]};
              state <= !tx_fifo_empty ?
                       `DM9000A_STATE_TX_DEST_SPIN_2 :
                       `DM9000A_STATE_TX_DEST_2;

              tx_fifo_rd_req <= !tx_fifo_empty;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= !tx_fifo_empty;
              enet_rd_n <= 1'b1;
           end
           //Spin after destination address (cycle 3).
           `DM9000A_STATE_TX_DEST_SPIN_2: begin
              state <= `DM9000A_STATE_TX_SRC_0;
              
              tx_fifo_rd_req <= 1'b0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Transmit source address (cycle 1).
           `DM9000A_STATE_TX_SRC_0: begin
              data_out <= {MAC_ADDRESS[39:32],MAC_ADDRESS[47:40]};
              state <= `DM9000A_STATE_TX_SRC_SPIN_0;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after source address (cycle 1).
           `DM9000A_STATE_TX_SRC_SPIN_0: begin
              state <= `DM9000A_STATE_TX_SRC_1;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Transmit source address (cycle 2).
           `DM9000A_STATE_TX_SRC_1: begin
              data_out <= {MAC_ADDRESS[23:16],MAC_ADDRESS[31:24]};
              state <= `DM9000A_STATE_TX_SRC_SPIN_1;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after source address (cycle 2).
           `DM9000A_STATE_TX_SRC_SPIN_1: begin
              state <= `DM9000A_STATE_TX_SRC_2;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Transmit source address (cycle 3).
           `DM9000A_STATE_TX_SRC_2: begin
              data_out <= {MAC_ADDRESS[7:0],MAC_ADDRESS[15:8]};
              state <= `DM9000A_STATE_TX_SRC_SPIN_2;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after source address (cycle 3).
           `DM9000A_STATE_TX_SRC_SPIN_2: begin
              state <= `DM9000A_STATE_TX_ETHERTYPE;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Transmit EtherType.
           `DM9000A_STATE_TX_ETHERTYPE: begin
              data_out <= tx_fifo_rd_data;
              state <= !tx_fifo_empty ?
                       `DM9000A_STATE_TX_ETHERTYPE_SPIN :
                       `DM9000A_STATE_TX_ETHERTYPE;

              tx_fifo_rd_req <= !tx_fifo_empty;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= !tx_fifo_empty;
              enet_rd_n <= 1'b1;
           end
           //Spin after EtherType.
           `DM9000A_STATE_TX_ETHERTYPE_SPIN: begin
              state <= `DM9000A_STATE_TX_DATA;
              
              tx_fifo_rd_req <= 1'b0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Transmit next data word (16b).
           `DM9000A_STATE_TX_DATA: begin
              data_out <= tx_fifo_rd_data;
              state <= !tx_fifo_empty ?
                       `DM9000A_STATE_TX_DATA_SPIN :
                       `DM9000A_STATE_TX_DATA;

              tx_length <= tx_fifo_empty ? tx_length :
                            tx_length==11'd1 ? 11'd0 :
                            tx_length-11'd2;
              tx_fifo_rd_req <= !tx_fifo_empty;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= !tx_fifo_empty;
              enet_rd_n <= 1'b1;
           end
           //Spin after data transmission.
           `DM9000A_STATE_TX_DATA_SETUP_SPIN: begin
              state <= tx_length==11'd0 ?
                        `DM9000A_STATE_IDLE :
                        `DM9000A_STATE_TX_DATA;
              
              tx_fifo_rd_req <= 1'b0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Setup TX control register.
           `DM9000A_STATE_TXC_SETUP: begin
              data_out <= `DM9000A_REG_TXCR1;
              state <= `DM9000A_STATE_TXC_SETUP_SPIN;

              enet_cmd <= `DM9000A_TYPE_INDEX;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Spin after TX control setup.
           `DM9000A_STATE_TXC_SETUP_SPIN: begin
              state <= `DM9000A_STATE_TX_LENH;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Start transmission.
           `DM9000A_STATE_TX_START: begin
              data_out <= `DM9000A_BIT_TXCR1_TXREQ;
              state <= `DM9000A_STATE_IDLE;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end

           /////////////////////////
           // Packet RX Sequence
           /////////////////////////
           
           //Receive packet data words.
           //Complete RX sequence:
           //  --Setup read register (1 cycle).
           //  --Spin (1 cycle).
           //  --Assert read (1 cycle).
           //  --Retrieve status (1 cycle).
           //  --Assert read (1 cycle).
           //  --Retrieve packet length (1 cycle).
           //  Repeat (length-4)/2 times.
           //  --Assert read (1 cycle).
           //  --Retrieve data words (1 cycle).
           //  Repeat 2 times.
           //  --Assert read (1 cycle).
           //  --Discard CRC word (1 cycle).
           //Total time: 6+length cycles.
           
           //Spin after index register setup.
           `DM9000A_STATE_RX_SETUP_SPIN: begin
              state <= `DM9000A_STATE_RX_STATUS_0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Read status word and check packet flags.
           `DM9000A_STATE_RX_STATUS_0: begin
              state <= `DM9000A_STATE_RX_STATUS_1;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b0;
           end
           `DM9000A_STATE_RX_STATUS_1: begin
              state <= `DM9000A_STATE_RX_LEN_0;

              rx_bad_packet <= (enet_data[`DM9000A_PKT_STATUS_STATUS] & BAD_PACKET_FLAGS)!=8'h0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Read packet length. Block if the data FIFO
           //ever fills up, until space is available.
           `DM9000A_STATE_RX_LEN_0: begin
              state <= rx_halt ?
                       `DM9000A_STATE_RX_LEN_0 :
                       `DM9000A_STATE_RX_LEN_1;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= rx_halt;
           end
           `DM9000A_STATE_RX_LEN_1: begin
              state <= `DM9000A_STATE_RX_0;

              //Store the packet length (without CRC)
              //to the RX FIFO only if the packet is valid.
              rx_fifo_wr_data <= enet_data-16'd4;
              rx_fifo_wr_req <= !rx_bad_packet;

              //Note: The length reported by the DM9000A
              //      includes 4B for the Ethernet CRC.
              //      Also, the length is forced to 64B
              //      for runt (<64B) packets.
              rx_length <= enet_data-16'd4;

              rx_odd_length <= enet_data[0];

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Receive frame data. Block if the data FIFO
           //ever fills up, until space is available.
           `DM9000A_STATE_RX_0: begin
              state <= rx_length==16'd0 ? `DM9000A_STATE_RX_CRC_0 :
                       rx_halt ? `DM9000A_STATE_RX_0 :
                       `DM9000A_STATE_RX_1;

              //Decrement packet length by one word.
              rx_length <= rx_halt ? rx_length :
                           rx_length==16'd1 ? 16'd0 :
                           rx_length-16'd2;
              
              rx_fifo_wr_req <= 1'b0;

              enet_wr_n <= 1'b1;
              enet_rd_n <= rx_halt && rx_length!=16'd0;
           end
           `DM9000A_STATE_RX_1: begin
              state <= `DM9000A_STATE_RX_0;

              //Store data to FIFO.
              rx_fifo_wr_data <= rx_length==16'd0 && rx_odd_length ?
                                 {8'h0,enet_data[7:0]} :
                                 enet_data;
              
              //Flag a write to the FIFO if the packet is valid.
              rx_fifo_wr_req <= !rx_bad_packet;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Discard CRC (2 words).
           `DM9000A_STATE_RX_CRC_0: begin
              state <= `DM9000A_STATE_RX_CRC_1;
              
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           `DM9000A_STATE_RX_CRC_1: begin
              state <= `DM9000A_STATE_RX_CRC_2;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b0;
           end
           `DM9000A_STATE_RX_CRC_2: begin
              state <= `DM9000A_STATE_IDLE;

              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           default: begin
              state <= `DM9000A_STATE_IDLE;

              enet_cmd <= `DM9000A_TYPE_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
         endcase
      end
   end // always @ (posedge clk_enet)

   //An issue is in progress when not in the idle state.
   //Additionally, an issue is flagged as still in progress
   //when a read result has not been stored.
   //Issues include packet RX and TX.
   wire issue_in_progress;
   assign issue_in_progress = state!=`DM9000A_STATE_IDLE || ~enet_rd_n;

   //Only put data on the line when issuing a command
   //or writing a data value to the DM9000A.
   assign enet_data = ~enet_wr_n ? data_out :
                      16'hzzzz;

   ////////////////////
   // Command Control
   ////////////////////

   //FIXME Add a watchdog if possible.

   //Command state variable.
   `PRESERVE reg [`DM9000A_CMD_STATE_RANGE] cmd_state;

   //An in-progress transmission has finished when
   //a completion interrupt is dispatched.
   assign tx_finished = cmd_state==`DM9000A_CMD_STATE_TX_COMPLETE;

   //The command state machine is paused whenever
   //spinning for a command, or when an issue is
   //already in progress.
   //Note: spin_next allows a command to forego
   //      issuing an instruction if desired.
   wire cmd_paused;
   reg spin_next;
   assign cmd_paused = issue_in_progress ||
                       spin_next ||
                       cmd_state==`DM9000A_CMD_STATE_SPIN;

   //An issue always ready when the command
   //state machine is not idle or paused.
   assign issue_ready = !cmd_paused &&
                        cmd_state!=`DM9000A_CMD_STATE_IDLE;

   reg [`DM9000A_CMD_SPIN_RANGE] cmd_spin_count;
   reg [`DM9000A_CMD_STATE_RANGE] cmd_post_spin_state;
   reg [7:0] interrupt_flags;
   reg [2:0] address_position;
   always @(posedge clk_enet) begin
      if(reset) begin
         //Go to PHY spin state after reset in order
         //to let DM9000A power-on-reset finish.
         cmd_state <= `DM9000A_CMD_STATE_SPIN;
         cmd_spin_count <= `DM9000A_PHY_SPIN_MAX_COUNT;
         cmd_post_spin_state <= `DM9000A_CMD_STATE_RESET;
         
         initializing <= 1'b1;
         link_status <= 1'b0;
         
         address_position <= 3'd0;
         interrupt_flags <= 8'h0;
         spin_next <= 1'b0;
         
         issue_read <= 1'b0;
         issue_register <= 16'h0;
         issue_data <= 16'h0;
      end
      else if(issue_in_progress) begin
         cmd_state <= cmd_state;
         initializing <= initializing;
         issue_read <= issue_read;
         issue_register <= issue_register;
         issue_data <= issue_data;
      end
      else begin
         case(cmd_state)
           ////////////////////
           // Miscellaneous
           ////////////////////

           //Idle until an interrupt is received.
           `DM9000A_CMD_STATE_IDLE: begin
              cmd_state <= enet_int ? `DM9000A_CMD_STATE_IRQ : cmd_state;
              initializing <= 1'b0;
              issue_read <= 1'b0;
              issue_register <= issue_register;
              issue_data <= issue_data;
           end // case: `DM9000A_CMD_STATE_IDLE
           //Spin for desired number of cycles, then continue.
           `DM9000A_CMD_STATE_SPIN: begin
              cmd_spin_count <= cmd_spin_count>`DM9000A_CMD_SPIN_WIDTH'd0 ?
                                 cmd_spin_count-`DM9000A_CMD_SPIN_WIDTH'd1 :
                                 cmd_spin_count;
              cmd_state <= cmd_spin_count!=`DM9000A_CMD_SPIN_WIDTH'd0 ? cmd_state :
                           cmd_post_spin_state;
              issue_read <= issue_read;
              issue_register <= issue_register;
              issue_data <= issue_data;
           end

           /////////////////////////
           // Interrupt Handler
           /////////////////////////

           //Interrupt received. First, disable all interrupts.
           `DM9000A_CMD_STATE_IRQ: begin
              cmd_state <= `DM9000A_CMD_STATE_IRQ_STATUS;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_IMR;
              issue_data <= `DM9000A_BIT_IMR_PAR;
           end
           //Next, retrieve the interrupt status byte.
           `DM9000A_CMD_STATE_IRQ_STATUS: begin
              cmd_state <= `DM9000A_CMD_STATE_IRQ_CLEAR;
              issue_read <= 1'b1;
              issue_register <= `DM9000A_REG_ISR;
           end
           //Store and clear interrupt flags.
           `DM9000A_CMD_STATE_IRQ_CLEAR: begin
              cmd_state <= `DM9000A_CMD_STATE_DISPATCH;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_ISR;
              issue_data <= `DM9000A_BIT_ISR_ALL;
              spin_next <= 1'b1;
              
              interrupt_flags <= data_out[7:0];
           end
           //Check remaining interrupt flags and dispatch
           //interrupt handlers as necessary.
           `DM9000A_CMD_STATE_DISPATCH: begin
              cmd_state <= interrupt_flags[`DM9000A_ISR_POS_PT] ? `DM9000A_CMD_STATE_TX_COMPLETE :
                           interrupt_flags[`DM9000A_ISR_POS_PR] ? `DM9000A_CMD_STATE_RX_PACKET_0 :
                           interrupt_flags[`DM9000A_ISR_POS_LNKCHG] ? `DM9000A_CMD_STATE_LINK_CHANGE :
                           `DM9000A_CMD_STATE_IRQ_FINISH;
              spin_next <= !interrupt_flags[`DM9000A_ISR_POS_PT];
           end
           //Interrupts handled. Re-enable all interrupts.
           `DM9000A_CMD_STATE_IRQ_FINISH: begin
              cmd_state <= `DM9000A_CMD_STATE_IDLE;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_IMR;
              issue_data <= INTERRUPT_FLAGS;
           end
           //Link status changed. Read network status,
           //then update system with new link status.
           `DM9000A_CMD_STATE_LINK_CHANGE: begin
              cmd_state <= ~spin_next ?
                           `DM9000A_CMD_STATE_LINK_CHANGE :
                           `DM9000A_CMD_STATE_DISPATCH;
              issue_read <= 1'b1;
              issue_register <= `DM9000A_REG_NSR;
              spin_next <= 1'b1;

              link_status <= (data_out & `DM9000A_BIT_NSR_LINK)==`DM9000A_BIT_NSR_LINK;
              
              interrupt_flags <= interrupt_flags & ~(`DM9000A_BIT8_ISR_LNKCHG);
           end
           //Transmission has completed.
           `DM9000A_CMD_STATE_TX_COMPLETE: begin
              cmd_state <= `DM9000A_CMD_STATE_DISPATCH;
              spin_next <= 1'b1;
              
              interrupt_flags <= interrupt_flags & ~(`DM9000A_BIT8_ISR_PT);
           end
           //Prefetch packet status word and check if a packet
           //is available to receive. If so, start reception,
           //otherwise return to dispatch.
           //If a packet is available, the packet ready byte
           //will be 1. If not, it will be 0. Any other value
           //indicates an error and should force a reset.
           //FIXME Add error reset condition.
           //FIXME If status[1:0] is not 0b00 or 0b01 reset.
           `DM9000A_CMD_STATE_RX_PACKET_0: begin
              cmd_state <= ~spin_next ? `DM9000A_CMD_STATE_RX_PACKET_0 :
                           data_out[`DM9000A_PKT_STATUS_READY]==8'd1 ? `DM9000A_CMD_STATE_RX_PACKET_1 :
                           //data_out[`DM9000A_PKT_STATUS_READY_LOW]!=2'd0 ?  : //FIXME Force reset!
                           `DM9000A_CMD_STATE_DISPATCH;
              issue_read <= 1'b1;
              issue_register <= `DM9000A_REG_MEM_RD_PF;
              spin_next <= 1'b1;
              
              interrupt_flags <= interrupt_flags & ~(`DM9000A_BIT8_ISR_PR);
           end
           //A packet is available. Trigger the issue state
           //machine to receive it by issuing a read to the
           //RD_INC register, then check if additional
           //packets are available. This requires a spin state
           //to ensure that issue_register is setup before
           //issuing the read.
           `DM9000A_CMD_STATE_RX_PACKET_1: begin
              cmd_state <= spin_next ?
                           `DM9000A_CMD_STATE_RX_PACKET_1 :
                           `DM9000A_CMD_STATE_RX_PACKET_0;
              issue_read <= 1'b1;
              issue_register <= `DM9000A_REG_MEM_RD_INC;
              spin_next <= 1'b0;
           end

           ////////////////////
           // Initialization
           ////////////////////
           
           //Reset DM9000A module.
           `DM9000A_CMD_STATE_RESET: begin
              cmd_state <= `DM9000A_CMD_STATE_SPIN;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_NCR;
              issue_data <= `DM9000A_BIT_NCR_RST;
              cmd_spin_count <= `DM9000A_RESET_SPIN_MAX_COUNT;
              cmd_post_spin_state <= `DM9000A_CMD_STATE_PHY;
           end
           //Power-up PHY.
           `DM9000A_CMD_STATE_PHY: begin
              cmd_state <= `DM9000A_CMD_STATE_SPIN;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_GPR;
              issue_data <= 16'h0;
              cmd_spin_count <= `DM9000A_PHY_SPIN_MAX_COUNT;
              cmd_post_spin_state <= `DM9000A_CMD_STATE_NSR;
           end
           //Clear TX and wake status bits.
           `DM9000A_CMD_STATE_NSR: begin
              cmd_state <= `DM9000A_CMD_STATE_ISR;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_NSR;
              issue_data <= (`DM9000A_BIT_NSR_WAKE | `DM9000A_BIT_NSR_TX2_END | `DM9000A_BIT_NSR_TX1_END);
           end
           //Clear interrupt flags.
           `DM9000A_CMD_STATE_ISR: begin
              cmd_state <= `DM9000A_CMD_STATE_MAC;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_ISR;
              issue_data <= `DM9000A_BIT_ISR_ALL;

              //Reset address position for MAC setup.
              address_position <= 3'd0;
           end
           //Setup MAC address. This state takes 6 register
           //write iterations, then sets up the multicast
           //address setup state.
           `DM9000A_CMD_STATE_MAC: begin
              cmd_state <= address_position<3'd5 ?
                            `DM9000A_CMD_STATE_MAC :
                            `DM9000A_CMD_STATE_MULTICAST;
              issue_read <= 1'b0;
              issue_register <= address_position==3'd0 ? `DM9000A_REG_PAR_0 :
                                address_position==3'd1 ? `DM9000A_REG_PAR_1 :
                                address_position==3'd2 ? `DM9000A_REG_PAR_2 :
                                address_position==3'd3 ? `DM9000A_REG_PAR_3 :
                                address_position==3'd4 ? `DM9000A_REG_PAR_4 :
                                `DM9000A_REG_PAR_5;
              issue_data <= address_position==3'd0 ? {8'h0,MAC_ADDRESS[7:0]} :
                            address_position==3'd1 ? {8'h0,MAC_ADDRESS[15:8]} :
                            address_position==3'd2 ? {8'h0,MAC_ADDRESS[23:16]} :
                            address_position==3'd3 ? {8'h0,MAC_ADDRESS[31:24]} :
                            address_position==3'd4 ? {8'h0,MAC_ADDRESS[39:32]} :
                            {8'h0,MAC_ADDRESS[47:40]};
              address_position <= address_position<3'd5 ?
                                  address_position+3'd1 :
                                  3'd0;
           end
           //Setup multicast address. This state takes 8
           //register write iterations.
           //Note: the MSB of the multicast address is forced to 1
           //      to enable reception of broadcast packets.
           //FIXME Non-broadcast isn't functioning.
           `DM9000A_CMD_STATE_MULTICAST: begin
              cmd_state <= address_position<3'd7 ?
                            `DM9000A_CMD_STATE_MULTICAST :
                            `DM9000A_CMD_STATE_RXCR;
              issue_read <= 1'b0;
              issue_register <= address_position==3'd0 ? `DM9000A_REG_MAR_0 :
                                address_position==3'd1 ? `DM9000A_REG_MAR_1 :
                                address_position==3'd2 ? `DM9000A_REG_MAR_2 :
                                address_position==3'd3 ? `DM9000A_REG_MAR_3 :
                                address_position==3'd4 ? `DM9000A_REG_MAR_4 :
                                address_position==3'd5 ? `DM9000A_REG_MAR_5 :
                                address_position==3'd6 ? `DM9000A_REG_MAR_6 :
                                `DM9000A_REG_MAR_7;
              issue_data <= address_position==3'd0 ? {8'h0,MULTICAST_ADDRESS[7:0]} :
                            address_position==3'd1 ? {8'h0,MULTICAST_ADDRESS[15:8]} :
                            address_position==3'd2 ? {8'h0,MULTICAST_ADDRESS[23:16]} :
                            address_position==3'd3 ? {8'h0,MULTICAST_ADDRESS[31:24]} :
                            address_position==3'd4 ? {8'h0,MULTICAST_ADDRESS[39:32]} :
                            address_position==3'd5 ? {8'h0,MULTICAST_ADDRESS[47:40]} :
                            address_position==3'd6 ? {8'h0,MULTICAST_ADDRESS[55:48]} :
                            BROADCAST_EN ? {8'h0,1'b1,MULTICAST_ADDRESS[62:56]} :
                            {8'h0,MULTICAST_ADDRESS[63:56]};
              address_position <= address_position<3'd7 ?
                                  address_position+3'd1 :
                                  3'd0;
           end
           //Enable RX with promiscuous mode.
           //FIXME Non-promiscuous isn't functioning.
           `DM9000A_CMD_STATE_RXCR: begin
              cmd_state <= `DM9000A_CMD_STATE_IMR;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_RXCR;
              issue_data <= PROMISCUOUS_EN ?
                            (`DM9000A_BIT_RXCR_PRMSC | `DM9000A_BIT_RXCR_RXEN) :
                            (`DM9000A_BIT_RXCR_RXEN);
           end
           //Enable read/write pointer auto-wrap, link change, and RX interrupts.
           `DM9000A_CMD_STATE_IMR: begin
              cmd_state <= `DM9000A_CMD_STATE_IDLE;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_IMR;
              issue_data <= INTERRUPT_FLAGS;
           end
           default: begin
              cmd_state <= `DM9000A_CMD_STATE_IDLE;
              issue_read <= issue_read;
              issue_register <= issue_register;
              issue_data <= issue_data;
           end
         endcase
      end
   end
   
endmodule