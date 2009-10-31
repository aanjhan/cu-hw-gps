module fll_truncate(
    input [4:0]       index,
    input [18:0]      in,
    output reg [14:0] out);

   //FIXME Parameters with preprocessor or defines.
   parameter INDEX_WIDTH = 1;
   parameter INPUT_WIDTH = 1;
   parameter OUTPUT_WIDTH = 1;
   parameter SIGNED = 1;

   //Note: For a signed truncation, the bits returned
   //      are a concatenation of the sign bit and
   //      the OUTPUT_WIDTH bits starting at the index.
   always @(index or in) begin
      case(index)
        5'd17: out <= {in[18],in[17:4]};
        5'd16: out <= {in[18],in[16:3]};
        5'd15: out <= {in[18],in[15:2]};
        5'd14: out <= {in[18],in[14:1]};
        default: out <= {in[18],in[13:0]};
      endcase
   end
endmodule