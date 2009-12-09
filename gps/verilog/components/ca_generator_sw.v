`include "global.vh"

`define TAP_1 7:4
`define TAP_2 3:0

module ca_generator_sw(
    input                     reset,
    input                     enable,
    //Code interface.
    input [`PRN_RANGE]        prn,
    output                    out,
    //C/A generator state.
    input [10:1]              g1_in,
    input [10:1]              g2_in,
    input [`CA_CS_RANGE]      code_shift_in,
    output reg [10:1]         g1_out,
    output reg [10:1]         g2_out,
    output reg [`CA_CS_RANGE] code_shift_out);

   //Generate output bit from PRN-specified taps.
   reg [7:0]        taps;
   assign out=g1_out[10]^(g2_out[taps[`TAP_1]]^g2_out[taps[`TAP_2]]);

   //Update shift registers and code shift.
   always @(*) begin
      code_shift_out<=reset ? 10'd0 :
                      !enable ? code_shift_in :
                      code_shift_in==10'd1022 ? 10'd0 :
                      code_shift_in+10'd1;
      g1_out<=reset ? 10'h3FF :
              !enable ? g1_in :
              g1_in<<1 | (g1_in[3]^g1_in[10]);
      g2_out<=reset ? 10'h3FF :
              !enable ? g2_in :
              g2_in<<1 | (g2_in[2]^g2_in[3]^g2_in[6]^g2_in[8]^g2_in[9]^g2_in[10]);
   end

   always @(prn) begin
      case(prn)
        5'd0: taps<={4'd2,4'd6};
        5'd1: taps<={4'd3,4'd7};
        5'd2: taps<={4'd4,4'd8};
        5'd3: taps<={4'd5,4'd9};
        5'd4: taps<={4'd1,4'd9};
        5'd5: taps<={4'd2,4'd10};
        5'd6: taps<={4'd1,4'd8};
        5'd7: taps<={4'd2,4'd9};
        5'd8: taps<={4'd3,4'd10};
        5'd9: taps<={4'd2,4'd3};
        5'd10: taps<={4'd3,4'd4};
        5'd11: taps<={4'd5,4'd6};
        5'd12: taps<={4'd6,4'd7};
        5'd13: taps<={4'd7,4'd8};
        5'd14: taps<={4'd8,4'd9};
        5'd15: taps<={4'd9,4'd10};
        5'd16: taps<={4'd1,4'd4};
        5'd17: taps<={4'd2,4'd5};
        5'd18: taps<={4'd3,4'd6};
        5'd19: taps<={4'd4,4'd7};
        5'd20: taps<={4'd5,4'd8};
        5'd21: taps<={4'd6,4'd9};
        5'd22: taps<={4'd1,4'd3};
        5'd23: taps<={4'd4,4'd6};
        5'd24: taps<={4'd5,4'd7};
        5'd25: taps<={4'd6,4'd8};
        5'd26: taps<={4'd7,4'd9};
        5'd27: taps<={4'd8,4'd10};
        5'd28: taps<={4'd1,4'd6};
        5'd29: taps<={4'd2,4'd7};
        5'd30: taps<={4'd3,4'd8};
        5'd31: taps<={4'd4,4'd9};
        default: taps<={4'd0,4'd0};
      endcase
   end
endmodule