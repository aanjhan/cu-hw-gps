`define TAP_1 7:4
`define TAP_2 3:0

module CAGenerator(clock,reset,prn,codeShift,out,g1);
   input            clock;
   input            reset;
   input      [4:0] prn;
   output reg [9:0] codeShift;
   output           out;

   output reg [10:1]       g1;
   reg [10:1]       g2;
   reg [7:0]        taps;
   
   assign out=g1[10]^(g2[taps[`TAP_1]]^g2[taps[`TAP_2]]);

   always @(posedge clock or posedge reset) begin
      codeShift<=reset ? 10'd0 :
                 codeShift==10'd1022 ? 10'd0 :
                 codeShift+10'd1;
      g1<=reset ?
          10'h3FF :
          g1<<1 | (g1[3]^g1[10]);
      g2=reset ?
         10'h3FF :
         g2<<1 | (g2[2]^g2[3]^g2[6]^g2[8]^g2[9]^g2[10]);
   end

   always @(prn) begin
      case(prn)
        5'd1: taps<={4'd2,4'd6};
        5'd2: taps<={4'd3,4'd7};
        5'd3: taps<={4'd4,4'd8};
        5'd4: taps<={4'd5,4'd9};
        5'd5: taps<={4'd1,4'd9};
        5'd6: taps<={4'd2,4'd10};
        5'd7: taps<={4'd1,4'd8};
        5'd8: taps<={4'd2,4'd9};
        5'd9: taps<={4'd3,4'd10};
        5'd10: taps<={4'd2,4'd3};
        5'd11: taps<={4'd3,4'd4};
        5'd12: taps<={4'd5,4'd6};
        5'd13: taps<={4'd6,4'd7};
        5'd14: taps<={4'd7,4'd8};
        5'd15: taps<={4'd8,4'd9};
        5'd16: taps<={4'd9,4'd10};
        5'd17: taps<={4'd1,4'd4};
        5'd18: taps<={4'd2,4'd5};
        5'd19: taps<={4'd3,4'd6};
        5'd20: taps<={4'd4,4'd7};
        5'd21: taps<={4'd5,4'd8};
        5'd22: taps<={4'd6,4'd9};
        5'd23: taps<={4'd1,4'd3};
        5'd24: taps<={4'd4,4'd6};
        5'd25: taps<={4'd5,4'd7};
        5'd26: taps<={4'd6,4'd8};
        5'd27: taps<={4'd7,4'd9};
        5'd28: taps<={4'd8,4'd10};
        5'd29: taps<={4'd1,4'd6};
        5'd30: taps<={4'd2,4'd7};
        5'd31: taps<={4'd3,4'd8};
        5'd32: taps<={4'd4,4'd9};
        default: taps<={4'd0,4'd0};
      endcase
   end
endmodule