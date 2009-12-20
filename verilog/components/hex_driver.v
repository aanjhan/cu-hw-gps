module hex_driver(
    input [3:0]      value,
    input            enable,
    output reg [6:0] display);
    
    always @(value or enable) begin
       if(!enable)display<=7'h7F;
       else begin
        case(value)
        4'h0: display<=7'b1000000;
        4'h1: display<=7'b1111001;
        4'h2: display<=7'b0100100;
        4'h3: display<=7'b0110000;
        4'h4: display<=7'b0011001;
        4'h5: display<=7'b0010010;
        4'h6: display<=7'b0000010;
        4'h7: display<=7'b1111000;
        4'h8: display<=7'b0000000;
        4'h9: display<=7'b0010000;
        4'hA: display<=7'b0001000;
        4'hB: display<=7'b0000011;
        4'hC: display<=7'b1000110;
        4'hD: display<=7'b0100001;
        4'hE: display<=7'b0000110;
        4'hF: display<=7'b0001110;
        endcase // case (value)
       end
    end
endmodule