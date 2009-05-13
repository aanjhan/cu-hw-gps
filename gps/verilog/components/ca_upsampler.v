module ca_upsampler(
    input              clk,
    input              reset,
    input              enable,
    input [4:0]        prn,
    output reg [14:0]  code_shift,
    output             out,
    //Seek control.
    input              seek_en,
    input [14:0]       seek_target,
    output wire        seeking /* synthesis keep */,
    //Debug outputs.
    output wire        ca_clk,
    output wire [9:0]  ca_code_shift);

   //C/A chipping rate phase increment
   //for DDS to yeild 1.023MHz from 16.8MHz.
   localparam [19:0] CA_RATE_INC = 20'd1021613;

   //Determine the next code shift value
   //for seek termination.
   wire [14:0] next_code_shift /* synthesis keep */;
   assign next_code_shift = code_shift=='d16799 ? 15'h0 : (code_shift+15'h1);

   //Target is coming up if it is the next shift
   //value and the shift is enabled.
   wire target_upcoming /* synthesis keep */;
   assign target_upcoming = next_code_shift==seek_target && ca_clk_en_km1;

   //The seek target has been reached when
   //the current code shift is equal to
   //the target value.
   wire target_reached /* synthesis keep */;
   assign target_reached = code_shift==seek_target;

   //We are seeking when seeking has been
   //enabled and the target has not been reached.
   assign seeking = seek_en && !(target_upcoming | target_reached);

   //Advance the clock when the system is
   //enabled (data available) or when seeking.
   wire ca_clk_en /* synthesis keep */;
   assign ca_clk_en = enable | seeking;

   //Pipe clock enable signal for 1 cycle
   //to meet timing requirements.
   wire ca_clk_en_km1 /* synthesis keep */;
   delay ca_clock_delay(.clk(clk),
                        .in(ca_clk_en),
                        .out(ca_clk_en_km1));

   always @(posedge clk) begin
      code_shift <= reset ? 15'h0 :
                    !ca_clk_en_km1 ? code_shift :
                    next_code_shift;
   end
   
   //Generate C/A code clock from reference
   //clock signal.
   wire ca_clk_n;
   dds2 #(.ACC_WIDTH(24),
         .PHASE_INC_WIDTH(20),
         .OUTPUT_WIDTH(1))
     ca_clock_gen(.clk(clk),
                  .reset(reset),
                  .enable(ca_clk_en_km1),
                  .inc(CA_RATE_INC),
                  .out(ca_clk_n));

   //Strobe C/A clock for 1 cycle.
   strobe ca_strobe(.clk(clk),
                    .reset(reset),
                    .in(~ca_clk_n),
                    .out(ca_clk));

   //Generate C/A code bit for given PRN.
   ca_generator ca_gen(.clk(clk),
                       .reset(reset),
                       .enable(ca_clk),
                       .prn(prn),
                       .code_shift(ca_code_shift),
                       .out(out));
endmodule