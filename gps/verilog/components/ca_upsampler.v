`include "global.vh"
`include "ca_upsampler.vh"
`include "channel__ca_upsampler.vh"

`define DEBUG
`include "debug.vh"

module ca_upsampler(
    input                       clk,
    input                       reset,
    input                       enable,
    //Control interface.
    input [4:0]                 prn,
    input [`CA_PHASE_INC_RANGE] phase_inc_offset,
    //C/A code output interface.
    output reg [`CS_RANGE]      code_shift,
    output                      out_early,
    output                      out_prompt,
    output                      out_late,
    //Seek control.
    input                       seek_en,
    input [`CS_RANGE]           seek_target,
    output wire                 seeking,
    output wire                 target_reached,
    //Debug outputs.
    output wire                 ca_clk,
    output wire [9:0]           ca_code_shift);

   //Force the code to asdvance on reset such that
   //the prompt code is at code shift 0.
   reg resetting;
   always @(posedge clk) begin
      resetting <= reset ? 1'b1 :
                   code_shift==`CS_WIDTH'd0 ? 1'b0 :
                   resetting;
   end

   //Internal seek signals, used to allow reset advances.
   wire seek_en_int;
   wire [`CS_RANGE] seek_target_int;
   assign seek_en_int = resetting ? 1'b1 : seek_en;
   assign seek_target_int = resetting ? `CS_WIDTH'd0 : seek_target;

   //Determine the next code shift value
   //for seek termination.
   wire [`CS_RANGE] next_code_shift;
   assign next_code_shift = code_shift==`MAX_CODE_SHIFT ?
                            {`CS_WIDTH{1'b0}} :
                            (code_shift+{{(`CS_WIDTH-1){1'b0}},1'h1});

   //Target is coming up if it is the next shift
   //value and the shift is enabled.
   wire target_upcoming;
   assign target_upcoming = next_code_shift==seek_target_int && pl_update_en && seek_en_int;

   //The seek target has been reached when
   //the current code shift is equal to
   //the target value.
   assign target_reached = code_shift==seek_target_int;

   //We are seeking when seeking has been
   //enabled and the target has not been reached.
   assign seeking = seek_en_int && !target_upcoming;

   //Advance the clock when the system is
   //enabled (data available) or when seeking.
   `KEEP wire ca_clk_en;
   assign ca_clk_en = ((~seek_en_int) & enable) | (seeking && !target_reached);

   //Pipe clock enable signal for 1 cycle
   //to meet timing requirements.
   //FIXME Is this still needed? If so, change the pl_update_en
   //FIXME delay to use this, but be careful of the target_upcoming
   //FIXME condition with the added delay. If this is enabled,
   //FIXME add 1 to CA_UPSAMPLER_DELAY in subchannel.v.
   /*wire ca_clk_en_km1;
   delay ca_clock_delay(.clk(clk),
                        .reset(reset),
                        .in(ca_clk_en),
                        .out(ca_clk_en_km1));*/

   //Delay prompt and late updates by one cycle
   //to account for extra cycle when updating
   //DDS and C/A generator.
   wire pl_update_en;
   delay bit_clk_delay(.clk(clk),
                       .reset(reset),
                       .in(ca_clk_en),
                       .out(pl_update_en));

   always @(posedge clk) begin
      code_shift <= reset ? `CS_RESET_VALUE :
                    !pl_update_en ? code_shift :
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
                  .reset(reset),
                  .enable(ca_clk_en),
                  .inc(resetting ?
                       `CA_RATE_INC :
                       `CA_RATE_INC+phase_inc_offset),
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
                      .enable(pl_update_en),
                      .in(out_early),
                      .out(out_prompt));
   
   delay_en #(.DELAY(`CHIPS_LEAD_LAG))
     bit_delay_late(.clk(clk),
                    .reset(reset),
                    .enable(pl_update_en),
                    .in(out_prompt),
                    .out(out_late));
endmodule