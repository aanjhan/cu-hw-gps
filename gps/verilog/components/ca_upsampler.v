module ca_upsampler(
    input              clk,
    input              reset,
    input              enable,
    input [4:0]        prn,
    output reg [(CS_WIDTH-1):0]  code_shift,
    output             out,
    //Seek control.
    input              seek_en,
    input [(CS_WIDTH-1):0]       seek_target,
    output wire        seeking,
    //Debug outputs.
    output wire        ca_clk,
    output wire [9:0]  ca_code_shift);

   `include "common_functions.vh"
   
   localparam FS = 16800000;
   localparam F_CA = 1023000;
   localparam T_CA = 0.001;
   
   localparam F_RES = 1;
   localparam F_DOPP_MAX = 6000;
   localparam ACC_WIDTH = log2(FS/F_RES);
   localparam PHASE_INC_WIDTH = log2((1<<ACC_WIDTH)*F_DOPP_MAX/FS);

   localparam [(PHASE_INC_WIDTH-1):0] CA_RATE_INC = (1<<ACC_WIDTH)*F_CA/FS;
   localparam CS_WIDTH = max_width(FS*T_CA);
   localparam MAX_CODE_SHIFT = 'd16799;//real_to_int((FS*T_CA)-1);

   //C/A chipping rate phase increment
   //for DDS to yeild 1.023MHz from 16.8MHz.
   //localparam [19:0] CA_RATE_INC = 20'd1021613;

   //Determine the next code shift value
   //for seek termination.
   wire [(CS_WIDTH-1):0] next_code_shift;
   assign next_code_shift = code_shift==MAX_CODE_SHIFT ? {CS_WIDTH{1'b0}} : (code_shift+{{(CS_WIDTH-1){1'b0}},1'h1});

   //Target is coming up if it is the next shift
   //value and the shift is enabled.
   wire target_upcoming;
   assign target_upcoming = next_code_shift==seek_target && ca_clk_en_km1;

   //The seek target has been reached when
   //the current code shift is equal to
   //the target value.
   wire target_reached;
   assign target_reached = code_shift==seek_target;

   //We are seeking when seeking has been
   //enabled and the target has not been reached.
   assign seeking = seek_en && !(target_upcoming | target_reached);

   //Advance the clock when the system is
   //enabled (data available) or when seeking.
   wire ca_clk_en;
   assign ca_clk_en = enable | seeking;

   //Pipe clock enable signal for 1 cycle
   //to meet timing requirements.
   wire ca_clk_en_km1;
   delay ca_clock_delay(.clk(clk),
                        .in(ca_clk_en),
                        .out(ca_clk_en_km1));

   always @(posedge clk) begin
      code_shift <= reset ? {CS_WIDTH{1'b0}} :
                    !ca_clk_en_km1 ? code_shift :
                    next_code_shift;
   end

   //Reset the C/A DDS unit at code shift
   //wrap-around to maintain code alignment.
   wire ca_clk_reset;
   assign ca_clk_reset = code_shift==MAX_CODE_SHIFT;
   
   //Generate C/A code clock from reference
   //clock signal.
   wire ca_clk_n;
   dds2 #(.ACC_WIDTH(ACC_WIDTH),
         .PHASE_INC_WIDTH(PHASE_INC_WIDTH),
         .OUTPUT_WIDTH(1))
     ca_clock_gen(.clk(clk),
                  .reset(reset | ca_clk_reset),
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