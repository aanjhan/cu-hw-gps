`undef DEBUG
//`define DEBUG
`include "debug.vh"

module sampler(
    input            clk_sample,
    input            reset,
    //Packet data FIFO interface.
    input            packet_empty,
    input [15:0]     packet_data,
    output wire      packet_read,
    //Sample interface.
    output reg       sample_valid,
    output reg [2:0] sample_data,
    //Debug.
    output reg [31:0] total_sample_count);
      
   //When there are less than two samples in the
   //buffer (there are at least 16b available for
   //a FIFO read), read a word from the FIFO.
   `PRESERVE reg [2:0]  sample_count;
   assign packet_read = !packet_empty && sample_count<3'd2;

   ////////////////////
   // Sample Generator
   ////////////////////

   `PRESERVE reg [17:0] sample_buffer;
   `PRESERVE reg [1:0]  sample_extra;
   always @(posedge clk_sample) begin
      if(reset) begin
         sample_valid <= 1'b0;
         sample_count <= 3'd0;
         sample_extra <= 2'd0;
         sample_buffer <= 18'h0;
         sample_data <= 3'd0;

         total_sample_count <= 32'd0;
      end
      else begin
         //Flag when samples are valid.
         sample_valid <= sample_count>3'd0;

         total_sample_count <= sample_count>3'd0 ?
                               total_sample_count+32'd1 :
                               total_sample_count;
         
         //Words contain 5 whole 3b samples, and one extra
         //bit. Increment the sample count by 6 if there
         //are already 2 extra bits available, and by
         //5 otherwise.
         sample_count <= sample_count>3'd1 ? sample_count-3'd1 :
                         packet_empty ? 3'd0 :
                         sample_extra==2'd2 ? 3'd6 :
                         3'd5;
      
         //Each word has one extra bit. Increment count
         //by one until a whole sample (3b) is built.
         sample_extra <= !packet_read ? sample_extra :
                         sample_extra==2'd2 ? 2'd0 :
                         sample_extra+2'd1;
         
         //Shift the buffer left by one sample each cycle,
         //and append a data word when appropriate.
         sample_buffer <= sample_count>3'd1 ? {3'h0,sample_buffer[17:3]} :
                          packet_empty ? (sample_count==3'd1 ?
                                          {3'h0,sample_buffer[17:3]} :
                                          sample_buffer) :
                          sample_extra==2'd0 ? {2'h0,packet_data} :
                          sample_count==3'd1 ? (sample_extra==2'd1 ?
                                                {1'h0,packet_data,sample_buffer[3]} :
                                                {packet_data,sample_buffer[4:3]}) :
                          (sample_extra==2'd1 ?
                           {1'h0,packet_data,sample_buffer[0]} :
                           {packet_data,sample_buffer[1:0]});
         
         //Sample data is the lowest 3 bits in the buffer.
         sample_data <= sample_buffer[2:0];
      end
   end // always @ (negedge clk_sample)

endmodule