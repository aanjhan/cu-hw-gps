`include "../components/global.vh"
`include "top__channel.vh"

module DE2_TOP (
    // Clock Input
    input         CLOCK_27,    // 27 MHz
    input         CLOCK_50,    // 50 MHz
    input         EXT_CLOCK,   // External Clock
    // Push Button
    input  [3:0]  KEY,         // Pushbutton[3:0]
    // DPDT Switch
    input  [17:0] SW,          // Toggle Switch[17:0]
    // 7-SEG Dispaly
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

   // Turn on all display
   assign LCD_ON    = 1'b1;
   assign LCD_BLON  = 1'b1;
   
   // All inout port turn to tri-state
   assign FL_DQ     = 8'hzz;
   assign SRAM_DQ   = 16'hzzzz;
   assign OTG_DATA  = 16'hzzzz;
   assign LCD_DATA  = 8'hzz;
   assign SD_DAT    = 1'bz;
   assign ENET_DATA = 16'hzzzz;
   assign GPIO_0    = 36'hzzzzzzzzz;
   assign GPIO_1    = 36'hzzzzzzzzz;

   wire   clk_200;
   wire   clk_50, clk_50_m3ns;
   wire   clk_16_8;
   wire   pll_locked;
   assign clk_50 = CLOCK_50;
   system_pll system_pll0(.inclk0(clk_50),
                          .c0(clk_200),
                          .c1(clk_16_8),
                          .c2(clk_50_m3ns),
                          .locked(pll_locked));

   wire   global_reset;
   assign global_reset = ~pll_locked /*| ~KEY[0]*/;

   wire [7:0] leds;
   (* keep *) wire [7:0] gps_data;
   data_feed_nios data_feed(.clk_0(clk_50),
                            .reset_n(~global_reset),
                            .rxd_to_the_data_uart(UART_RXD),
                            .txd_from_the_data_uart(UART_TXD),
                            .out_port_from_the_gps_data(gps_data),
                            .out_port_from_the_leds(leds),
                            .zs_addr_from_the_sdram(DRAM_ADDR),
                            .zs_ba_from_the_sdram({DRAM_BA_1,DRAM_BA_0}),
                            .zs_cas_n_from_the_sdram(DRAM_CAS_N),
                            .zs_cke_from_the_sdram(DRAM_CKE),
                            .zs_cs_n_from_the_sdram(DRAM_CS_N),
                            .zs_dq_to_and_from_the_sdram(DRAM_DQ),
                            .zs_dqm_from_the_sdram({DRAM_UDQM, DRAM_LDQM}),
                            .zs_ras_n_from_the_sdram(DRAM_RAS_N),
                            .zs_we_n_from_the_sdram(DRAM_WE_N),
                            .in_port_to_the_start(~KEY[3]));
   assign DRAM_CLK = clk_50_m3ns;

   wire clk_sample, feed_complete, reset;
   wire [2:0] data;
   assign clk_sample = gps_data[3];
   assign feed_complete = gps_data[6];
   assign reset = gps_data[7];
   assign data = gps_data[2:0];

   reg [15:0] count;
   always @(posedge clk_sample) begin
      count <= reset ? 'h0 : count+'h1;
   end

   wire [14:0] code_shift;
   wire [9:0]  ca_code_shift;
   wire        ca_bit;
   wire        ca_clk;
   wire [`ACC_RANGE] accumulator_i;
   wire [`ACC_RANGE] accumulator_q;
   wire        i2q2_valid;
   wire [`I2Q2_RANGE] i2q2_early;
   wire [`I2Q2_RANGE] i2q2_prompt;
   wire [`I2Q2_RANGE] i2q2_late;
   top sub(.clk(clk_200),
           .clk_sample(clk_sample),
           .global_reset(global_reset),
           .reset(reset),
           .prn(SW[4:0]),
           .feed_complete(feed_complete),
           .data(data),
           .seek_en(~KEY[0]),
           .seek_target(15'h0),
           .doppler({SW[15:8],8'h0}),
           .code_shift(code_shift),
           .ca_bit(ca_bit),
           .ca_clk(ca_clk),
           .ca_code_shift(ca_code_shift),
           .accumulator_i(accumulator_i),
           .accumulator_q(accumulator_q),
           .i2q2_valid(i2q2_valid),
           .i2q2_early(i2q2_early),
           .i2q2_prompt(i2q2_prompt),
           .i2q2_late(i2q2_late));

   wire [`I2Q2_RANGE] i2q2;
   assign i2q2 = SW[7:6]==2'h0 ? i2q2_early :
                 SW[7:6]==2'h1 ? i2q2_prompt :
                 i2q2_late;

   wire disp_acc, disp_comp, disp_shift, disp_i2q2;
   assign disp_acc = !SW[17] && !SW[16];
   assign disp_comp = SW[17] && !SW[16];
   assign disp_shift = !SW[17] && SW[16];
   assign disp_i2q2 = SW[17] && SW[16];
   
   assign LEDR[17] = disp_i2q2 ? i2q2_valid : KEY[2];
   assign LEDR[16] = clk_sample;
   assign LEDR[15] = ca_clk;
   assign LEDR[14:12] = gps_data[2:0];
   assign LEDR[11:5] = 'h0;
   assign LEDR[4:0] = SW[4:0];
   assign LEDG[8] = 1'b0;
   assign LEDG[7:0] = ca_code_shift[7:0];

   wire [6:0] hex7_value;
   hex_driver hex7(i2q2_valid ?
                   (KEY[2] ?
                    i2q2[(`I2Q2_WIDTH-1):(`I2Q2_WIDTH-1-3)] :
                    i2q2[31:28]) :
                   4'h0,hex7_value);
   assign HEX7 = reset ? 7'h7F :
                 disp_i2q2 ? hex7_value :
                 {~gps_data[2],6'h3F};
   
   hex_driver hex6(reset ? 4'h8 :
                   disp_i2q2 ?
                   (KEY[2] ?
                    i2q2[(`I2Q2_WIDTH-4):(`I2Q2_WIDTH-4-3)] :
                    i2q2[27:24]) :
                   {2'h0,gps_data[1:0]},
                   HEX6);

   wire [6:0] hex5_value;
   hex_driver hex5(i2q2_valid ?
                   (KEY[2] ?
                    i2q2[(`I2Q2_WIDTH-8):(`I2Q2_WIDTH-8-3)] :
                    i2q2[23:20]) :
                   4'h0,hex5_value);
   assign HEX5 = reset ? 7'h7F :
                 disp_i2q2 ? hex5_value :
                 {ca_bit,6'h3F};
   
   hex_driver hex4(disp_i2q2 ?
                   (KEY[2] ?
                    i2q2[(`I2Q2_WIDTH-12):(`I2Q2_WIDTH-12-3)] :
                    i2q2[19:16]) :
                   (KEY[2] ? accumulator_i[19:16] : accumulator_q[19:16]),
                   HEX4);
   
   hex_driver hex3(disp_i2q2 ?
                   (KEY[2] ?
                    i2q2[(`I2Q2_WIDTH-16):(`I2Q2_WIDTH-16-3)] :
                    i2q2[15:12] ) :
                   disp_shift ? {1'b0,code_shift[14:12]} :
                   disp_comp ? count[7:4] :
                   (KEY[2] ? accumulator_i[15:12] : accumulator_q[15:12]),
                   HEX3);
   hex_driver hex2(disp_i2q2 ?
                   (KEY[2] ?
                    i2q2[(`I2Q2_WIDTH-20):(`I2Q2_WIDTH-20-3)] :
                    i2q2[11:8] ) :
                   disp_shift ? code_shift[11:8] :
                   disp_comp ? count[3:0] :
                   (KEY[2] ? accumulator_i[11:8] : accumulator_q[11:8]),
                   HEX2);
   hex_driver hex1(disp_i2q2 ?
                   (KEY[2] ?
                    i2q2[(`I2Q2_WIDTH-24):(`I2Q2_WIDTH-24-3)] :
                    i2q2[7:4] ) :
                   disp_shift ? code_shift[7:4] :
                   (KEY[2] ? accumulator_i[7:4] : accumulator_q[7:4]),
                   HEX1);
   hex_driver hex0(disp_i2q2 ?
                   (KEY[2] ?
                    i2q2[(`I2Q2_WIDTH-28):(`I2Q2_WIDTH-28-3)] :
                    i2q2[3:0] ) :
                   disp_shift ? code_shift[3:0] :
                   (KEY[2] ? accumulator_i[3:0] : accumulator_q[3:0]),
                   HEX0);
endmodule