module dll_truncate(
    input [5:0]       index,
    input [35:0]      in,
    output reg [10:0] out);

   //FIXME Parameters with preprocessor or defines.
   
   always @(index or in) begin
      case(index)
        6'd35: out <= in[35:25];
        6'd34: out <= in[34:24];
        6'd33: out <= in[33:23];
        6'd32: out <= in[32:22];
        6'd31: out <= in[31:21];
        6'd30: out <= in[30:20];
        6'd29: out <= in[29:19];
        6'd28: out <= in[28:18];
        6'd27: out <= in[27:17];
        6'd26: out <= in[26:16];
        6'd25: out <= in[25:15];
        6'd24: out <= in[24:14];
        6'd23: out <= in[23:13];
        6'd22: out <= in[22:12];
        6'd21: out <= in[21:11];
        6'd20: out <= in[20:10];
        6'd19: out <= in[19:9];
        6'd18: out <= in[18:8];
        6'd17: out <= in[17:7];
        6'd16: out <= in[16:6];
        6'd15: out <= in[15:5];
        6'd14: out <= in[14:4];
        6'd13: out <= in[13:3];
        6'd12: out <= in[12:2];
        6'd11: out <= in[11:1];
        default: out <= in[10:0];
      endcase
   end
endmodule