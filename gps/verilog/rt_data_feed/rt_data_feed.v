module rt_data_feed(
    input              clk,
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
    //Crap
    output wire [15:0] rxp_h,
    output wire [15:0] rxp_l);

   //Ethernet data RX FIFO.
   wire        fifo_wr_clk;
   wire        fifo_wr_req;
   wire [15:0] fifo_wr_data;
   wire        fifo_wr_full;
   wire        fifo_rd_req;
   wire [15:0] fifo_rd_data;
   wire        fifo_rd_empty;
   wire [7:0]  fifo_rd_available;
   rx_data_fifo rx_fifo(.wrclk(fifo_wr_clk),
                        .data(fifo_wr_data),
                        .wrreq(fifo_wr_req),
                        .wrfull(fifo_wr_full),
                        .rdclk(clk),
                        .rdreq(fifo_rd_req),
                        .q(fifo_rd_data),
                        .rdempty(fifo_rd_empty),
                        .wrusedw(fifo_rd_available));

   //DM9000A Ethernet controller module.
   dm9000a_controller dm9000a(.clk(clk_50),
                              .reset(global_reset),
                              .enet_clk(ENET_CLK),
                              .enet_int(ENET_INT),
                              .enet_rst_n(ENET_RST_N),
                              .enet_cs_n(ENET_CS_N),
                              .enet_cmd(ENET_CMD),
                              .enet_wr_n(ENET_WR_N),
                              .enet_rd_n(ENET_RD_N),
                              .enet_data(ENET_DATA),
                              .rxp_h(rxp_h),
                              .rxp_l(rxp_l));
   
endmodule