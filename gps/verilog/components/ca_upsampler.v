`include "global.vh"
`include "ca_upsampler.vh"

module ca_upsampler(
    input                  clk,
    input                  reset,
    input                  enable,
    input [4:0]            prn,
    output reg [`CS_RANGE] code_shift,
    output                 out_early,
    output                 out_prompt,
    output                 out_late,
    //Seek control.
    input                  seek_en,
    input [`CS_RANGE]      seek_target,
    output wire            seeking,
    output wire            target_reached,
    //Debug outputs.
    output wire            ca_clk,
    output wire [9:0]      ca_code_shift);

   //Determine the next code shift value
   //for seek termination.
   wire [`CS_RANGE] next_code_shift;
   assign next_code_shift = code_shift==`MAX_CODE_SHIFT ?
                            {`CS_WIDTH{1'b0}} :
                            (code_shift+{{(`CS_WIDTH-1){1'b0}},1'h1});

   //Target is coming up if it is the next shift
   //value and the shift is enabled.
   wire target_upcoming;
   assign target_upcoming = next_code_shift==seek_target && ca_clk_en_km1;

   //The seek target has been reached when
   //the current code shift is equal to
   //the target value.
   assign target_reached = code_shift==seek_target;

   //We are seeking when seeking has been
   //enabled and the target has not been reached.
   assign seeking = seek_en && !(target_upcoming | target_reached);

   //Advance the clock when the system is
   //enabled (data available) or when seeking.
   wire ca_clk_en;
   assign ca_clk_en = ((~seek_en) & enable) | seeking;

   //Pipe clock enable signal for 1 cycle
   //to meet timing requirements.
   wire ca_clk_en_km1;
   delay ca_clock_delay(.clk(clk),
                        .reset(reset),
                        .in(ca_clk_en),
                        .out(ca_clk_en_km1));

   always @(posedge clk) begin
      code_shift <= reset ? `CS_RESET_VALUE :
                    !ca_clk_en_km1 ? code_shift :
                    next_code_shift;
   end

   //Reset the C/A DDS unit at code shift
   //wrap-around to maintain code alignment.
   wire ca_clk_reset;
   assign ca_clk_reset = code_shift==`CS_RESET_VALUE;
   
   //Generate C/A code clock from reference
   //clock signal.
   wire ca_clk_n;
   dds #(.ACC_WIDTH(`CA_ACC_WIDTH),
         .PHASE_INC_WIDTH(`CA_PHASE_INC_WIDTH),
         .OUTPUT_WIDTH(1))
     ca_clock_gen(.clk(clk),
                  .reset(reset | ca_clk_reset),
                  .enable(ca_clk_en_km1),
                  .inc(`CA_RATE_INC),
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
                       .out(out_early));

   //Delay early code for prompt and late.
   delay_en #(.DELAY(`CHIPS_LEAD_LAG))
     bit_delay_prompt(.clk(clk),
                      .reset(reset),
                      .enable(ca_clk_en_km1),
                      .in(out_early),
                      .out(out_prompt));
   
   delay_en #(.DELAY(`CHIPS_LEAD_LAG))
     bit_delay_late(.clk(clk),
                    .reset(reset),
                    .enable(ca_clk_en_km1),
                    .in(out_prompt),
                    .out(out_late));
endmodule