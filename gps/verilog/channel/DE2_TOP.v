`include "../components/global.vh"
`include "top__channel.vh"
`include "../components/channel.vh"
`include "../components/channel__tracking_loops.vh"

`define DEBUG
`include "../components/debug.vh"

module DE2_TOP (
    // Clock Input
    input         CLOCK_27,    // 27 MHz
    input         CLOCK_50,    // 50 MHz
    input         EXT_CLOCK,   // External Clock
    // Push Button
    input  [3:0]  KEY,         // Pushbutton[3:0]
    // DPDT Switch
    input  [17:0] SW,          // Toggle Switch[17:0]
    // 7-SEG Display
    output [6:0]  HEX0,        // Seven Segment Digit 0
    output [6:0]  HEX1,        // Seven Segment Digit 1
    output [6:0]  HEX2,        // Seven Segment Digit 2
    output [6:0]  HEX3,        // Seven Segment Digit 3
    output [6:0]  HEX4,        // Seven Segment Digit 4
    output [6:0]  HEX5,        // Seven Segment Digit 5
    output [6:0]  HEX6,        // Seven Segment Digit 6
    output [6:0]  HEX7,        // Seven Segment Digit 7
    // LED
    output [8:0]  LEDG,        // LED Green[8:0]
    output [17:0] LEDR,        // LED Red[17:0]
    // UART
    output        UART_TXD,    // UART Transmitter
    input         UART_RXD,    // UART Receiver
    // IRDA
    output        IRDA_TXD,    // IRDA Transmitter
    input         IRDA_RXD,    // IRDA Receiver
    // SDRAM Interface
    inout  [15:0] DRAM_DQ,     // SDRAM Data bus 16 Bits
    output [11:0] DRAM_ADDR,   // SDRAM Address bus 12 Bits
    output        DRAM_LDQM,   // SDRAM Low-byte Data Mask 
    output        DRAM_UDQM,   // SDRAM High-byte Data Mask
    output        DRAM_WE_N,   // SDRAM Write Enable
    output        DRAM_CAS_N,  // SDRAM Column Address Strobe
    output        DRAM_RAS_N,  // SDRAM Row Address Strobe
    output        DRAM_CS_N,   // SDRAM Chip Select
    output        DRAM_BA_0,   // SDRAM Bank Address 0
    output        DRAM_BA_1,   // SDRAM Bank Address 0
    output        DRAM_CLK,    // SDRAM Clock
    output        DRAM_CKE,    // SDRAM Clock Enable
    // Flash Interface
    inout  [7:0]  FL_DQ,       // FLASH Data bus 8 Bits
    output [21:0] FL_ADDR,     // FLASH Address bus 22 Bits
    output        FL_WE_N,     // FLASH Write Enable
    output        FL_RST_N,    // FLASH Reset
    output        FL_OE_N,     // FLASH Output Enable
    output        FL_CE_N,     // FLASH Chip Enable
    // SRAM Interface
    inout  [15:0] SRAM_DQ,     // SRAM Data bus 16 Bits
    output [17:0] SRAM_ADDR,   // SRAM Address bus 18 Bits
    output        SRAM_UB_N,   // SRAM High-byte Data Mask 
    output        SRAM_LB_N,   // SRAM Low-byte Data Mask 
    output        SRAM_WE_N,   // SRAM Write Enable
    output        SRAM_CE_N,   // SRAM Chip Enable
    output        SRAM_OE_N,   // SRAM Output Enable
    // ISP1362 Interface
    inout  [15:0] OTG_DATA,    // ISP1362 Data bus 16 Bits
    output [1:0]  OTG_ADDR,    // ISP1362 Address 2 Bits
    output        OTG_CS_N,    // ISP1362 Chip Select
    output        OTG_RD_N,    // ISP1362 Write
    output        OTG_WR_N,    // ISP1362 Read
    output        OTG_RST_N,   // ISP1362 Reset
    output        OTG_FSPEED,  // USB Full Speed, 0 = Enable, Z = Disable
    output        OTG_LSPEED,  // USB Low Speed,  0 = Enable, Z = Disable
    input         OTG_INT0,    // ISP1362 Interrupt 0
    input         OTG_INT1,    // ISP1362 Interrupt 1
    input         OTG_DREQ0,   // ISP1362 DMA Request 0
    input         OTG_DREQ1,   // ISP1362 DMA Request 1
    output        OTG_DACK0_N, // ISP1362 DMA Acknowledge 0
    output        OTG_DACK1_N, // ISP1362 DMA Acknowledge 1
    // LCD Module 16X2
    inout  [7:0]  LCD_DATA,    // LCD Data bus 8 bits
    output        LCD_ON,      // LCD Power ON/OFF
    output        LCD_BLON,    // LCD Back Light ON/OFF
    output        LCD_RW,      // LCD Read/Write Select, 0 = Write, 1 = Read
    output        LCD_EN,      // LCD Enable
    output        LCD_RS,      // LCD Command/Data Select, 0 = Command, 1 = Data
    // SD Card Interface
    inout         SD_DAT,      // SD Card Data
    inout         SD_DAT3,     // SD Card Data 3
    inout         SD_CMD,      // SD Card Command Signal
    output        SD_CLK,      // SD Card Clock
    // I2C
    inout         I2C_SDAT,    // I2C Data
    output        I2C_SCLK,    // I2C Clock
    // PS2
    input         PS2_DAT,     // PS2 Data
    input         PS2_CLK,     // PS2 Clock
    // USB JTAG link
    input         TDI,         // CPLD -> FPGA (data in)
    input         TCK,         // CPLD -> FPGA (clk)
    input         TCS,         // CPLD -> FPGA (CS)
    output        TDO,         // FPGA -> CPLD (data out)
    // VGA
    output        VGA_CLK,     // VGA Clock
    output        VGA_HS,      // VGA H_SYNC
    output        VGA_VS,      // VGA V_SYNC
    output        VGA_BLANK,   // VGA BLANK
    output        VGA_SYNC,    // VGA SYNC
    output [9:0]  VGA_R,       // VGA Red[9:0]
    output [9:0]  VGA_G,       // VGA Green[9:0]
    output [9:0]  VGA_B,       // VGA Blue[9:0]
    // Ethernet Interface
    inout  [15:0] ENET_DATA,   // DM9000A DATA bus 16Bits
    output        ENET_CMD,    // DM9000A Command/Data Select, 0 = Command, 1 = Data
    output        ENET_CS_N,   // DM9000A Chip Select
    output        ENET_WR_N,   // DM9000A Write
    output        ENET_RD_N,   // DM9000A Read
    output        ENET_RST_N,  // DM9000A Reset
    input         ENET_INT,    // DM9000A Interrupt
    output        ENET_CLK,    // DM9000A Clock 25 MHz
    // Audio CODEC
    inout         AUD_ADCLRCK, // Audio CODEC ADC LR Clock
    input         AUD_ADCDAT,  // Audio CODEC ADC Data
    inout         AUD_DACLRCK, // Audio CODEC DAC LR Clock
    output        AUD_DACDAT,  // Audio CODEC DAC Data
    inout         AUD_BCLK,    // Audio CODEC Bit-Stream Clock
    output        AUD_XCK,     // Audio CODEC Chip Clock
    // TV Decoder
    input  [7:0]  TD_DATA,     // TV Decoder Data bus 8 bits
    input         TD_HS,       // TV Decoder H_SYNC
    input         TD_VS,       // TV Decoder V_SYNC
    output        TD_RESET,    // TV Decoder Reset
    // GPIO
    inout  [35:0] GPIO_0,      // GPIO Connection 0
    inout  [35:0] GPIO_1       // GPIO Connection 1
);
   
   //Set all GPIO to tri-state.
   assign GPIO_0 = 36'hzzzzzzzzz;
   assign GPIO_1 = 36'hzzzzzzzzz;

   //Disable audio codec.
   assign AUD_DACDAT = 1'b0;
   assign AUD_XCK    = 1'b0;

   //Disable flash.
   assign FL_ADDR  = 22'h0;
   assign FL_CE_N  = 1'b1;
   assign FL_DQ    = 8'hzz;
   assign FL_OE_N  = 1'b1;
   assign FL_RST_N = 1'b1;
   assign FL_WE_N  = 1'b1;

   //Disable LCD.
   assign LCD_BLON = 1'b0;
   assign LCD_DATA = 8'hzz;
   assign LCD_EN   = 1'b0;
   assign LCD_ON   = 1'b0;
   assign LCD_RS   = 1'b0;
   assign LCD_RW   = 1'b0;

   //Disable OTG.
   assign OTG_ADDR    = 2'h0;
   assign OTG_CS_N    = 1'b1;
   assign OTG_DACK0_N = 1'b1;
   assign OTG_DACK1_N = 1'b1;
   assign OTG_FSPEED  = 1'b1;
   assign OTG_DATA    = 16'hzzzz;
   assign OTG_LSPEED  = 1'b1;
   assign OTG_RD_N    = 1'b1;
   assign OTG_RST_N   = 1'b1;
   assign OTG_WR_N    = 1'b1;

   //Disable SD card interface.
   assign SD_DAT = 1'bz;
   assign SD_CLK = 1'b0;

   //Disable SRAM.
   assign SRAM_ADDR = 18'h0;
   assign SRAM_CE_N = 1'b1;
   assign SRAM_DQ   = 16'hzzzz;
   assign SRAM_LB_N = 1'b1;
   assign SRAM_OE_N = 1'b1;
   assign SRAM_UB_N = 1'b1;
   assign SRAM_WE_N = 1'b1;

   //Disable VGA.
   assign VGA_CLK   = 1'b0;
   assign VGA_BLANK = 1'b0;
   assign VGA_SYNC  = 1'b0;
   assign VGA_HS    = 1'b0;
   assign VGA_VS    = 1'b0;
   assign VGA_R     = 10'h0;
   assign VGA_G     = 10'h0;
   assign VGA_B     = 10'h0;

   //Disable all other peripherals.
   assign I2C_SCLK = 1'b0;
   assign IRDA_TXD = 1'b0;
   assign TDO = 1'b0;

   //Generate SDRAM clock.
   wire clk_50;
   wire clk_50_m3ns;
   wire sdram_pll_locked;
   sdram_pll sdram_pll0(.inclk0(CLOCK_27),
                        .c0(clk_50),
                        .c1(clk_50_m3ns),
                        .locked(sdram_pll_locked));
   assign TD_RESET = 1'b1;

   //Generate 200MHz clock and 16.8MHz sample clock.
   wire clk_200;
   wire clk_16_8;
   wire system_pll_locked;
   system_pll system_pll0(.inclk0(CLOCK_50),
                          .c0(clk_200),
                          .c1(clk_16_8),
                          .locked(system_pll_locked));

   wire po_reset;
   power_on_reset por(.clk(clk_50),
                      .reset(po_reset));

   wire   global_reset;
   assign global_reset = ~system_pll_locked |
                         ~sdram_pll_locked |
                         po_reset |
                         ~KEY[0];

   //Generate ~1ms sample clock.
   reg clk_sample;
   reg [21:0] sample_clk_count;
   always @(posedge clk_16_8) begin
      if(global_reset) begin
         sample_clk_count <= 22'd0;
         clk_sample <= 1'b0;
      end
      else begin
         sample_clk_count <= sample_clk_count==22'd0 ?
                             22'd16800 :
                             sample_clk_count-22'd1;
         clk_sample <= sample_clk_count==22'd0 ? ~clk_sample : clk_sample;
      end
   end

   //Real-time sample data feed.
   wire link_status;
   wire sample_valid;
   wire [2:0] sample_data;
   wire [8:0] words_available;
   wire [8:0] pkt_count;
   wire [8:0] good_pkt_count;
   rt_data_feed data_feed(.clk_50(CLOCK_50),
                          .reset(global_reset),
                          .enet_clk(ENET_CLK),
                          .enet_int(ENET_INT),
                          .enet_rst_n(ENET_RST_N),
                          .enet_cs_n(ENET_CS_N),
                          .enet_cmd(ENET_CMD),
                          .enet_wr_n(ENET_WR_N),
                          .enet_rd_n(ENET_RD_N),
                          .enet_data(ENET_DATA),
                          .clk_sample(~KEY[3] | clk_sample/*clk_16_8*/),
                          .sample_valid(sample_valid),
                          .sample_data(sample_data),
                          .link_status(link_status),
                          .words_available(words_available),
                          .packet_count(pkt_count),
                          .good_packet_count(good_pkt_count),
                          .halt(SW[1]),
                          .halt_packet(SW[2]));

   //0=Acquisition, 1=Tracking.
   wire [`MODE_RANGE] mode;
   assign mode = SW[0];

   wire [14:0] code_shift;
   wire        i2q2_valid;
   wire [`I2Q2_RANGE] i2q2_early;
   wire [`I2Q2_RANGE] i2q2_prompt;
   wire [`I2Q2_RANGE] i2q2_late;
   wire               tracking_ready;
   wire [`ACC_RANGE_TRACK] i_prompt_k;
   wire [`ACC_RANGE_TRACK] q_prompt_k;
   wire [`W_DF_RANGE] w_df_k;
   wire               acquisition_complete;
   wire [`I2Q2_RANGE] acq_peak_i2q2;
   wire [`ACC_RANGE] accumulator_i;
   wire [`ACC_RANGE] accumulator_q;
   wire [`DOPPLER_INC_RANGE] acq_peak_doppler;
   wire [`CS_RANGE]          acq_peak_code_shift;
   wire                      data_available;
   wire                      track_feed_complete;
   wire [`SAMPLE_COUNT_RANGE] sample_count;
   wire        ca_bit;
   wire        ca_clk;
   wire [9:0]  ca_code_shift;
   top sub(.clk(clk_200),
           .global_reset(global_reset),
           .mode(mode),
           //Sample data.
           .clk_sample(clk_sample),
           .sample_valid(sample_valid),
           .feed_reset(1'b0),
           .feed_complete(1'b0),
           .data(sample_data),
           //Code control.
           .prn(SW[4:0]),
           .code_shift(code_shift),
           //Channel history.
           .i2q2_valid(i2q2_valid),
           .i2q2_early(i2q2_early),
           .i2q2_prompt(i2q2_prompt),
           .i2q2_late(i2q2_late),
           .tracking_ready(tracking_ready),
           .i_prompt_k(i_prompt_k),
           .q_prompt_k(q_prompt_k),
           .w_df_k(w_df_k),
           //Acquisition results.
           .acquisition_complete(acquisition_complete),
           .acq_peak_i2q2(acq_peak_i2q2),
           .acq_peak_doppler(acq_peak_doppler),
           .acq_peak_code_shift(acq_peak_code_shift),
           //Other.
           .accumulator_i(accumulator_i),
           .accumulator_q(accumulator_q),
           .data_available(data_available),
           .track_feed_complete(track_feed_complete),
           .sample_count(sample_count),
           .ca_bit(ca_bit),
           .ca_clk(ca_clk),
           .ca_code_shift(ca_code_shift));

   receiver_back_end be(.clk_0(clk_50),
                        .reset_n(~global_reset),
                        .out_port_from_the_heart_beat_led(LEDG[0]),
                        .in_port_to_the_tracking_ready(tracking_ready),
                        .in_port_to_the_i_prompt(i_prompt_k),
                        .in_port_to_the_q_prompt(q_prompt_k),
                        .in_port_to_the_w_df(w_df_k),
                        .rxd_to_the_uart_0(UART_RXD),
                        .txd_from_the_uart_0(UART_TXD),
                        .zs_addr_from_the_sdram(DRAM_ADDR),
                        .zs_ba_from_the_sdram({DRAM_BA_1,DRAM_BA_0}),
                        .zs_cas_n_from_the_sdram(DRAM_CAS_N),
                        .zs_cke_from_the_sdram(DRAM_CKE),
                        .zs_cs_n_from_the_sdram(DRAM_CS_N),
                        .zs_dq_to_and_from_the_sdram(DRAM_DQ),
                        .zs_dqm_from_the_sdram({DRAM_UDQM, DRAM_LDQM}),
                        .zs_ras_n_from_the_sdram(DRAM_RAS_N),
                        .zs_we_n_from_the_sdram(DRAM_WE_N));
   assign DRAM_CLK = clk_50_m3ns;

   wire disp_i_q, disp_words, disp_pkt, disp_pkt_good, disp_count;
   assign disp_i_q = SW[17];
   assign disp_words = SW[16];
   assign disp_count = SW[15];
   assign disp_pkt = SW[14];
   assign disp_pkt_good = SW[13];

   wire [`ACC_RANGE_TRACK] sel_i_q_value;
   assign sel_i_q_value = disp_i_q ? q_prompt_k : i_prompt_k;

   assign LEDR=disp_words ? {9'h0,words_available} :
               disp_count ? {3'h0,sample_count} :
               disp_pkt ? (disp_pkt_good ? {9'h0,good_pkt_count} : {9'h0,pkt_count}) :
               sel_i_q_value[17:0];
   assign LEDG[8] = link_status;
   assign LEDG[7] = tracking_ready;
   assign LEDG[6] = track_feed_complete;
   assign LEDG[5] = data_available;
   assign LEDG[4:2] = sample_data;
   assign LEDG[1] = sample_valid;

   hex_driver hex7(4'd0,1'b0,HEX7);
   hex_driver hex6(4'd0,1'b0,HEX6);
   hex_driver hex5(4'd0,1'b0,HEX5);
   hex_driver hex4({2'b0,sel_i_q_value[17:16]},1'b1,HEX4);
   hex_driver hex3(sel_i_q_value[15:12],1'b1,HEX3);
   hex_driver hex2(sel_i_q_value[11:8],1'b1,HEX2);
   hex_driver hex1(sel_i_q_value[7:4],1'b1,HEX1);
   hex_driver hex0(sel_i_q_value[3:0],1'b1,HEX0);
endmodule