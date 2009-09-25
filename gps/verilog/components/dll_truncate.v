module dll_truncate(
    input [6:0]       top,
    input [38:0]      in,
    output reg [13:0] out);

   //FIXME Parameters with preprocessor or defines.
   
   always @(top or in) begin
      case(top)
        7'd38: out <= in[38:25];
        7'd37: out <= in[37:24];
        7'd36: out <= in[36:23];
        7'd35: out <= in[35:22];
        7'd34: out <= in[34:21];
        7'd33: out <= in[33:20];
        7'd32: out <= in[32:19];
        7'd31: out <= in[31:18];
        7'd30: out <= in[30:17];
        7'd29: out <= in[29:16];
        7'd28: out <= in[28:15];
        7'd27: out <= in[27:14];
        7'd26: out <= in[26:13];
        7'd25: out <= in[25:12];
        7'd24: out <= in[24:11];
        7'd23: out <= in[23:10];
        7'd22: out <= in[22:9];
        7'd21: out <= in[21:8];
        7'd20: out <= in[20:7];
        7'd19: out <= in[19:6];
        7'd18: out <= in[18:5];
        7'd17: out <= in[17:4];
        7'd16: out <= in[16:3];
        7'd15: out <= in[15:2];
        7'd14: out <= in[14:1];
        default: out <= in[13:0];
      endcase
   end
endmodule