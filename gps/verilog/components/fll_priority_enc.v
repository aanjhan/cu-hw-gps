`include "global.vh"
`include "debug.vh"

module fll_priority_enc(
    input             clk,
    input [17:0]      in,
    output wire [4:0] out);

   //The priority encoder is divided into a two-
   //stage pipeline for timing requirements.
   
   //FIXME Parameters with preprocessor or defines.
   
   `PRESERVE reg [12:8] in_km1;
   `PRESERVE reg [4:0] pos;
   always @(posedge clk) begin
      casez(in[17:13])
        5'b1zzzz: pos <= 5'd17;
        5'b01zzz: pos <= 5'd16;
        5'b001zz: pos <= 5'd15;
        5'b0001z: pos <= 5'd14;
        5'b00001: pos <= 5'd13;
        default: pos <= 5'd0;
      endcase // casez (in[18:13])

      in_km1 <= in[12:8];
   end // always @ (posedge clk)

   `PRESERVE reg [4:0] pos_km1;
   always @(posedge clk) begin
      if(pos!=5'd0) begin
         pos_km1 <= pos;
      end
      else begin
         casez(in_km1)
           5'b1zzzz: pos_km1 <= 6'd12;
           5'b01zzz: pos_km1 <= 6'd11;
           5'b001zz: pos_km1 <= 6'd10;
           5'b0001z: pos_km1 <= 6'd9;
           5'b00001: pos_km1 <= 6'd8;
           default: pos_km1 <= 6'd7;
      endcase // casez (in_km1)
      end
   end

   assign out = pos_km1;
endmodule