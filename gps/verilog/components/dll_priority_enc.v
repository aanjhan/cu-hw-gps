`include "global.vh"
`include "debug.vh"

module dll_priority_enc(
    input             clk,
    input [38:0]      in,
    output wire [5:0] out);

   //The priority encoder is divided into a two-
   //stage pipeline for timing requirements.
   
   //FIXME Parameters with preprocessor or defines.
   
   `PRESERVE reg [25:14] in_km1;
   `PRESERVE reg [5:0] pos;
   always @(posedge clk) begin
      casez(in[38:26])
        13'b1zzzzzzzzzzzz: pos <= 6'd38;
        13'b01zzzzzzzzzzz: pos <= 6'd37;
        13'b001zzzzzzzzzz: pos <= 6'd36;
        13'b0001zzzzzzzzz: pos <= 6'd35;
        13'b00001zzzzzzzz: pos <= 6'd34;
        13'b000001zzzzzzz: pos <= 6'd33;
        13'b0000001zzzzzz: pos <= 6'd32;
        13'b00000001zzzzz: pos <= 6'd31;
        13'b000000001zzzz: pos <= 6'd30;
        13'b0000000001zzz: pos <= 6'd29;
        13'b00000000001zz: pos <= 6'd28;
        13'b000000000001z: pos <= 6'd27;
        13'b0000000000001: pos <= 6'd26;
        default: pos <= 6'd0;
      endcase // casez (in[38:26])

      in_km1 <= in[25:14];
   end // always @ (posedge clk)

   `PRESERVE reg [5:0] pos_km1;
   always @(posedge clk) begin
      if(pos!=6'd0) begin
         pos_km1 <= pos;
      end
      else begin
         casez(in_km1)
           12'b1zzzzzzzzzzz: pos_km1 <= 6'd25;
           12'b01zzzzzzzzzz: pos_km1 <= 6'd24;
           12'b001zzzzzzzzz: pos_km1 <= 6'd23;
           12'b0001zzzzzzzz: pos_km1 <= 6'd22;
           12'b00001zzzzzzz: pos_km1 <= 6'd21;
           12'b000001zzzzzz: pos_km1 <= 6'd20;
           12'b0000001zzzzz: pos_km1 <= 6'd19;
           12'b00000001zzzz: pos_km1 <= 6'd18;
           12'b000000001zzz: pos_km1 <= 6'd17;
           12'b0000000001zz: pos_km1 <= 6'd16;
           12'b00000000001z: pos_km1 <= 6'd15;
           12'b000000000001: pos_km1 <= 6'd14;
           default: pos_km1 <= 6'd13;
      endcase // casez (in_km1)
      end
   end

   assign out = pos_km1;
endmodule