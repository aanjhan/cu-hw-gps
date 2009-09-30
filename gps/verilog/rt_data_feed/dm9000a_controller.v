`include "dm9000a_controller.vh"

`define DEBUG
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
    input wire [15:0]  enet_data,//FIXME
    output wire [15:0]  enet_data_out,//FIXME
    //RX data FIFO interface.
    input              rx_fifo_full,
    output wire        rx_fifo_clk,
    output reg         rx_fifo_wr_req,
    output wire [15:0] rx_fifo_data,
    //Crap
    output reg [15:0]  rxp_h,
    output reg [15:0]  rxp_l);

   //Generate 25MHz control clock.
   wire clk_enet;
   dm9000a_clk_gen clk_gen(.clk(clk),
                           .clk_enet(clk_enet));
   assign rx_fifo_clk = clk_enet;

   //Ethernet control signals.
   assign enet_clk = clk_enet;
   assign enet_rst_n = 1'b1;
   assign enet_cs_n = 1'b0;

   //The following signals setup a command issue from
   //the initialization state machine to the control.
   wire       issue_ready;
   reg        issue_read;
   reg [15:0] issue_register;
   reg [15:0] issue_data;
   
   //Received packet information.
   `PRESERVE reg [1:0]  rx_word_type;
   reg [15:0] rx_length;
   reg [15:0] rx_data;
   reg        rx_bad_packet;

   //A packet is bad if any of the following flags are set.
   localparam BAD_PACKET_FLAGS = (`DM9000A_BIT_RXSR_RF |
                                  `DM9000A_BIT_RXSR_LCS |
                                  `DM9000A_BIT_RXSR_RWTO |
                                  `DM9000A_BIT_RXSR_PLE |
                                  `DM9000A_BIT_RXSR_AE |
                                  `DM9000A_BIT_RXSR_CE |
                                  `DM9000A_BIT_RXSR_FOE);
   
   //DM9000A control state machine - used to issue
   //a single command and send/receive subsequent data.
   //Also used to transmit/receive packet data.
   `PRESERVE reg [`DM9000A_STATE_RANGE] state;
   reg [15:0]                 data_out;
   reg                        writing;

   //Send RX data to FIFO.
   assign rx_fifo_data = rx_data;
   
   always @(posedge clk_enet) begin
      if(reset) begin
         writing <= 1'b0;
         data_out <= data_out;
         state <= `DM9000A_STATE_IDLE;

         rx_word_type <= `DM9000A_RX_WORD_TYPE_NONE;
         rx_fifo_wr_req <= 1'b0;

         enet_cmd <= `DM9000A_CMD_DATA;
         enet_wr_n <= 1'b1;
         enet_rd_n <= 1'b1;
      end
      else begin
         case(state)
           `DM9000A_STATE_IDLE: begin
              writing <= 1'b0;
              data_out <= ~enet_rd_n ? enet_data : data_out;
              state <= issue_ready ? `DM9000A_STATE_SETUP :
                       enet_int ? `DM9000A_STATE_RX_PREFETCH :
                       `DM9000A_STATE_IDLE;
              
              rx_word_type <= `DM9000A_RX_WORD_TYPE_NONE;
              rx_fifo_wr_req <= 1'b0;

              enet_cmd <= `DM9000A_CMD_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Setup register index and command type.
           `DM9000A_STATE_SETUP: begin
              writing <= ~issue_read;
              data_out <= issue_register;
              state <= issue_read ?
                       `DM9000A_STATE_READ :
                       `DM9000A_STATE_WRITE;

              enet_cmd <= `DM9000A_CMD_INDEX;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Read incoming register data.
           `DM9000A_STATE_READ: begin
              writing <= 1'b0;
              data_out <= data_out;
              state <= `DM9000A_STATE_IDLE;

              enet_cmd <= `DM9000A_CMD_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b0;
           end
           //Write data to DM9000A.
           `DM9000A_STATE_WRITE: begin
              writing <= 1'b1;
              data_out <= issue_data;
              state <= `DM9000A_STATE_IDLE;

              enet_cmd <= `DM9000A_CMD_DATA;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Setup RX data read - pre-fetch first word.
           //FIXME Clear interrupt flag?
           `DM9000A_STATE_RX_PREFETCH: begin
              writing <= 1'b0;
              data_out <= `DM9000A_REG_MEM_RD_PF;
              state <= `DM9000A_STATE_RX_PREFETCH_2;

              enet_cmd <= `DM9000A_CMD_INDEX;
              enet_wr_n <= 1'b0;
              enet_rd_n <= 1'b1;
           end
           //Issue read for pre-fetch register.
           `DM9000A_STATE_RX_PREFETCH_2: begin
              writing <= 1'b0;
              data_out <= data_out;
              state <= `DM9000A_STATE_RX_SPIN;

              rx_word_type <= `DM9000A_RX_WORD_TYPE_HEADER;

              enet_cmd <= `DM9000A_CMD_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b0;
           end
           //Spin 2 cycles on pre-fetches to let data become
           //available in DM9000A buffer. After the first cycle
           //of spin the status word is returned and should
           //begin 0x01, otherwise packet is invalid.
           `DM9000A_STATE_RX_SPIN: begin
              writing <= 1'b0;
              data_out <= data_out;
              state <= enet_rd_n==1'b0 ?
                       (enet_data[7:0]==8'h01 ?
                        `DM9000A_STATE_RX_SPIN :
                        `DM9000A_STATE_IDLE) :
                       `DM9000A_STATE_RX;

              rx_word_type <= `DM9000A_RX_WORD_TYPE_NONE;

              enet_cmd <= `DM9000A_CMD_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
           //Receive packet data words.
           //Complete RX sequence:
           //  --Assert pre-fetch (1 cycle).
           //  --Assert read for pre-fetch result (1 cycle).
           //  --Retrieve status, spin after pre-fetch (2 cycles).
           //  --Assert read (1 cycle).
           //  --Retrieve status (1 cycle).
           //  --Retrieve length (1 cycle).
           //  --Retrieve data words (length/2 cycles).
           `DM9000A_STATE_RX: begin
              writing <= 1'b0;
              data_out <= `DM9000A_REG_MEM_RD_INC;
              state <= enet_rd_n==1'b1 ? `DM9000A_STATE_RX :
                       rx_word_type==`DM9000A_RX_WORD_TYPE_HEADER ? `DM9000A_STATE_RX :
                       rx_word_type==`DM9000A_RX_WORD_TYPE_LEN ? `DM9000A_STATE_RX :
                       rx_length>16'd0 ? `DM9000A_STATE_RX :
                       `DM9000A_STATE_IDLE;
              
              rx_word_type <= enet_rd_n==1'b1 ? `DM9000A_RX_WORD_TYPE_HEADER :
                              rx_word_type==`DM9000A_RX_WORD_TYPE_HEADER ? `DM9000A_RX_WORD_TYPE_LEN :
                              `DM9000A_RX_WORD_TYPE_DATA;
              rx_length <= rx_word_type==`DM9000A_RX_WORD_TYPE_LEN ?
                           enet_data-16'd2 :
                           rx_length-16'd2;
              rx_data <= enet_data;
              //FIXME What if the FIFO is full?
              rx_fifo_wr_req <= rx_word_type==`DM9000A_RX_WORD_TYPE_DATA &&
                                !rx_bad_packet;
              //A packet is bad if the status byte in the
              //header contains any error flags.
              rx_bad_packet <= rx_word_type==`DM9000A_RX_WORD_TYPE_HEADER ?
                               ((enet_data[15:8]&BAD_PACKET_FLAGS)!=8'h0) :
                               rx_bad_packet;

              enet_cmd <= `DM9000A_CMD_INDEX;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b0;
           end
           default: begin
              writing <= 1'b0;
              data_out <= data_out;
              state <= `DM9000A_STATE_IDLE;

              enet_cmd <= `DM9000A_CMD_DATA;
              enet_wr_n <= 1'b1;
              enet_rd_n <= 1'b1;
           end
         endcase
      end
   end // always @ (posedge clk_enet)

   //A command is in progress when not in the idle state.
   wire issue_in_progress;
   assign issue_in_progress = state!=`DM9000A_STATE_IDLE;

   //Only put data on the line when issuing a command
   //or writing a data value to the DM9000A.
   /*assign enet_data = enet_cmd==`DM9000A_CMD_INDEX ? data_out :
                      writing ? data_out :
                      16'hzzzz;*/
   assign enet_data_out = enet_cmd==`DM9000A_CMD_INDEX ? data_out :
                      writing ? data_out :
                      16'hzzzz;

   //Initialization state machine.
   `PRESERVE reg [`DM9000A_INIT_STATE_RANGE] init_state;
   reg init_spinning;
   assign issue_ready = !issue_in_progress &&
                        !init_spinning &&
                        init_state!=`DM9000A_INIT_STATE_IDLE;
   
   reg [`DM9000A_INIT_SPIN_RANGE] init_spin_count;
   reg [`DM9000A_INIT_STATE_RANGE] init_post_spin_state;
   always @(posedge clk_enet) begin
      if(reset) begin
         //init_state <= `DM9000A_INIT_STATE_RESET;
         init_state <= `DM9000A_INIT_STATE_IDLE;
         //init_state <= `DM9000A_INIT_STATE_READ_RXPH;
         init_spinning <= 1'b0;
         issue_read <= 1'b0;
         issue_register <= 16'h0;
         issue_data <= 16'h0;
      end
      else if(issue_in_progress) begin
         init_spinning <= init_spinning;
         init_state <= init_state;
         issue_read <= issue_read;
         issue_register <= issue_register;
         issue_data <= issue_data;
      end
      else begin
         case(init_state)
           //Reset DM9000A module.
           `DM9000A_INIT_STATE_RESET: begin
              init_state <= `DM9000A_INIT_STATE_SPIN;
              init_spinning <= 1'b1;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_NCR;
              issue_data <= `DM9000A_BIT_NCR_RST;
              init_spin_count <= `DM9000A_RESET_SPIN_MAX_COUNT;
              init_post_spin_state <= `DM9000A_INIT_STATE_PHY;
           end
           //Power-up PHY.
           `DM9000A_INIT_STATE_PHY: begin
              init_state <= `DM9000A_INIT_STATE_SPIN;
              init_spinning <= 1'b1;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_GPR;
              issue_data <= ~`DM9000A_BIT_GPR_PHYPD;
              init_spin_count <= `DM9000A_PHY_SPIN_MAX_COUNT;
              init_post_spin_state <= `DM9000A_INIT_STATE_INTM;
           end
           //Enable read/write pointer auto-wrap and RX interrupt.
           `DM9000A_INIT_STATE_INTM: begin
              init_state <= `DM9000A_INIT_STATE_RXCR;
              init_spinning <= 1'b0;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_INTM;
              issue_data <= (`DM9000A_BIT_INTM_PAR | `DM9000A_BIT_INTM_PRI);
           end
           //Enable RX with promiscuous mode.
           `DM9000A_INIT_STATE_RXCR: begin
              init_state <= `DM9000A_INIT_STATE_READ_RXPH;
              init_spinning <= 1'b0;
              issue_read <= 1'b0;
              issue_register <= `DM9000A_REG_RXCR;
              issue_data <= (`DM9000A_BIT_RXCR_PRMSC | `DM9000A_BIT_RXCR_RXEN);//FIXME Promiscuous needed?
           end
           `DM9000A_INIT_STATE_READ_RXPH: begin
              init_state <= `DM9000A_INIT_STATE_READ_RXPL;
              init_spinning <= 1'b0;
              issue_read <= 1'b1;
              issue_register <= `DM9000A_REG_RX_PTR_H;
              issue_data <= issue_data;
           end
           `DM9000A_INIT_STATE_READ_RXPL: begin
              init_state <= `DM9000A_INIT_STATE_IDLE;
              init_spinning <= 1'b0;
              issue_read <= 1'b1;
              issue_register <= `DM9000A_REG_RX_PTR_L;
              issue_data <= issue_data;

              rxp_h <= enet_data;
           end
           `DM9000A_INIT_STATE_IDLE: begin
              init_state <= init_state;
              init_spinning <= 1'b0;
              issue_read <= 1'b0;
              issue_register <= issue_register;
              issue_data <= issue_data;

              rxp_l <= issue_read ? enet_data : rxp_l;//FIXME
           end
           `DM9000A_INIT_STATE_SPIN: begin
              init_spin_count <= init_spin_count-`DM9000A_INIT_SPIN_WIDTH'd1;
              init_state <= init_spin_count==`DM9000A_INIT_SPIN_WIDTH'd0 ?
                            init_post_spin_state :
                            init_state;
              init_spinning <= init_spin_count!=`DM9000A_INIT_SPIN_WIDTH'd0;
              issue_read <= issue_read;
              issue_register <= issue_register;
              issue_data <= issue_data;
           end
           default: begin
              init_state <= init_state;
              init_spinning <= 1'b0;
              issue_read <= issue_read;
              issue_register <= issue_register;
              issue_data <= issue_data;
           end
         endcase
      end
   end
   
endmodule