//C/A chipping rate phase increment
//for DDS to yeild 1.023MHz from 16.8MHz.
`define CA_RATE_INC 1021613

module ca_upsampler(
    input              clk,
    input              reset,
    input [4:0]        prn,
    output reg [14:0]  code_shift,
    output             out,
    //Seek control.
    input              clk_seek,
    input              seek_en,
    input [14:0]       seek_target,
    //Debug outputs.
    output wire        ca_clk,
    output wire [9:0]  ca_code_shift);

   wire seeking;
   assign seeking = seek_en && code_shift!=seek_target;

   wire clk_dds;
   assign clk_dds = seeking ? clk_seek : clk;
   
   always @(posedge clk_dds) begin
      code_shift <= reset ? 'h0 :
                    code_shift=='d16799 ? 'h0 :
                    code_shift+'h1;
   end
   
   //Generate C/A code clock from reference
   //clock signal.
   wire ca_clk_n;
   dds #(.ACC_WIDTH(24),
         .PHASE_INC_WIDTH(20),
         .OUTPUT_WIDTH(1))
     ca_clock_gen(.clk(clk_dds),
                  .reset(reset),
                  .inc(20'd`CA_RATE_INC),
                  .out(ca_clk_n));
   assign ca_clk = ~ca_clk_n;

   //Generate C/A code bit for given PRN.
   ca_generator ca_gen(.clk(ca_clk),
                       .reset(reset),
                       .prn(prn),
                       .code_shift(ca_code_shift),
                       .out(out));
endmodule