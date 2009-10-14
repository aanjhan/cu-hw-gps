module dll_truncate(
    input [4:0]       index,
    input [18:0]      in,
    output reg [8:0] out);

   //FIXME Parameters with preprocessor or defines.
   parameter INDEX_WIDTH = 1;
   parameter INPUT_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;
   
   always @(index or in) begin
      case(index)
        /*generate
           genvar i;
           for(i=INPUT_WIDTH-1;i>=OUTPUT_WIDTH;i=i-1) begin : trunc_gen
              INDEX_WIDTH'di: out <= in[i:i-(OUTPUT_WIDTH-1)];
           end
        default: out <= in[OUTPUT_WIDTH-1:0];
        endgenerate*/
        5'd18: out <= in[18:10];
        5'd17: out <= in[17:9];
        5'd16: out <= in[16:8];
        5'd15: out <= in[15:7];
        5'd14: out <= in[14:6];
        5'd13: out <= in[13:5];
        5'd12: out <= in[12:4];
        5'd11: out <= in[11:3];
        5'd10: out <= in[10:2];
        5'd9: out <= in[9:1];
        default: out <= in[8:0];
      endcase
   end
endmodule