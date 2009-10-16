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
    output reg [2:0]   sample_data,      
    //Debug signals.
    output wire        link_status,
    output wire        have_data,
    output wire [8:0]  words_available,
    output wire [15:0] data_out,
    //Crap
    output wire [17:0] samp_buffer,
    output wire [2:0]  samp_count,
    input              halt,
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
   wire [8:0]  fifo_rd_available;
   rx_data_fifo rx_fifo(.aclr(reset),
                        .wrclk(fifo_wr_clk),
                        .data(fifo_wr_data),
                        .wrreq(fifo_wr_req),
                        .wrfull(fifo_wr_full),
                        .rdclk(~clk_sample),
                        .rdreq(fifo_rd_req),
                        .q(fifo_rd_data),
                        .rdempty(fifo_rd_empty),
                        .rdusedw(fifo_rd_available));//FIXME Remove rdusedw.
   
   assign have_data = !fifo_rd_empty;
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
                              .rx_fifo_full(fifo_wr_full || halt),
                              .rx_fifo_clk(fifo_wr_clk),
                              .rx_fifo_wr_req(fifo_wr_req),
                              .rx_fifo_data(fifo_wr_data),
                              .link_status(link_status),
                              .rxp_h(rxp_h),
                              .rxp_l(rxp_l));
   
   //When there are less than two samples in the
   //buffer (there are at least 16b available for
   //a FIFO read), read a word from the FIFO.
   reg [2:0]  sample_count;
   assign fifo_rd_req = !fifo_rd_empty && sample_count<3'd2;

   reg [17:0] sample_buffer;
   reg [1:0]  sample_extra;
   always @(negedge clk_sample) begin
      //Words contain 5 whole 3b samples, and one extra
      //bit. Increment the sample count by 6 if there
      //are already 2 extra bits available, and by
      //5 otherwise.
      sample_count <= reset ? 3'd0 :
                      sample_count>3'd1 ? sample_count-3'd1 :
                      fifo_rd_empty ? (sample_count==3'd1 :
                                       3'd0 :
                                       sample_count) :
                      sample_extra==2'd2 ? sample_count+3'd6 :
                      sample_count+3'd5;
      
      //Each word has one extra bit. Increment count
      //by one until a whole sample (3b) is built.
      sample_extra <= reset ? 2'd0 :
                      !fifo_rd_req ? sample_extra :
                      sample_extra==2'd2 ? 2'd0 :
                      sample_extra+2'd1;

      //Shift the buffer left by one sample each cycle,
      //and append a data word when appropriate.
      sample_buffer <= reset ? 18'h0 :
                       sample_count>=3'd1 ? {2'h0,sample_buffer[16:3]} :
                       fifo_rd_empty ? (sample_count==3'd1 ?
                                        {2'h0,sample_buffer[16:3]} :
                                        sample_buffer) :
                       sample_extra==2'd0 ? {2'h0,fifo_rd_data} :
                       sample_count==3'd1 ? (sample_extra==2'd1 ?
                                             {1'h0,fifo_rd_data,sample_buffer[3]} :
                                             {fifo_rd_data,sample_buffer[4:3]}) :
                       (sample_extra==2'd1 ?
                        {1'h0,fifo_rd_data,sample_buffer[0]} :
                        {fifo_rd_data,sample_buffer[1:0]});

      //Sample data is the lowest 3 bits in the buffer.
      sample_data <= sample_buffer[2:0];
   end // always @ (negedge clk_sample)

   //FIXME Remove these.
   assign samp_buffer = sample_buffer;
   assign samp_count = sample_count;
   
endmodule