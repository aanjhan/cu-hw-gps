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
    output wire        seeking,             
    //Debug outputs.
    output wire        ca_clk,
    output wire [9:0]  ca_code_shift);

   //C/A chipping rate phase increment
   //for DDS to yeild 1.023MHz from 16.8MHz.
   localparam [19:0] CA_RATE_INC = 20'd1021613;

   //The seek target has been reached when
   //the current code shift is equal to
   //the target value.
   wire target_reached;
   assign target_reached = code_shift==seek_target;

   //We are seeking when seeking has been
   //enabled and the target has not been reached.
   assign seeking = seek_en && !target_reached;

   //Advance the clock when the system is
   //enabled (data available) or when seeking.
   wire advance;
   assign advance = enable | seeking;

   //Preload the clock DDS for one increment
   //after a system reset.
   reg ca_clk_preload;
   always @(posedge clk) begin
      ca_clk_preload <= reset ? 1'b1 : 1'b0;
   end

   //Enable the clock generator when advancing
   //or to preload after a reset.
   wire ca_clk_en;
   assign ca_clk_en = advance;// | ca_clk_preload;

   //Pipe clock enable signal for 1 cycle
   //to meet timing requirements.
   wire advance_km1;
   wire ca_clk_en_km1;
   delay #(.WIDTH(2))
     ca_clock_delay(.clk(clk),
                    .in({ca_clk_en,advance}),
                    .out({ca_clk_en_km1,advance_km1}));
   
   always @(posedge clk) begin
      code_shift <= reset ? 'h0 :
                    !advance_km1 ? code_shift :
                    code_shift=='d16799 ? 'h0 :
                    code_shift+'h1;
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