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
    //Debug signals.
    input              read_one,
    output wire        have_data,
    output wire [7:0]  words_available,
    output wire [15:0] data_out,
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

   strobe read_strobe(.clk(clk),
                      .reset(reset),
                      .in(read_one),
                      .out(fifo_rd_req));
   
   assign have_data = fifo_rd_available>8'd3;
   assign words_available = fifo_rd_available;
   assign data_out = fifo_rd_data;

   //DM9000A Ethernet controller module.
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
                              .rxp_h(rxp_h),
                              .rxp_l(rxp_l));
   
endmodule