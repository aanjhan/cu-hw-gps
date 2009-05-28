//`include "global.vh"

module mem_bank_mux( 
    ctrl,
    ad_passthrough,
    buf_1,
    buf_2,
    buf_3,
    buf_4,
    chan_1,
    chan_2,
    chan_3,
    chan_4,
    chan_5,
    chan_6,
    chan_7,
    chan_8,
    chan_9,
    chan_10
);
    
    //Data inputs from the direct A/D passthrough and the 4 data buffers
    input [2:0] ad_passthrough;
    input [2:0] buf_1;
    input [2:0] buf_2;
    input [2:0] buf_3;
    input [2:0] buf_4;
    
    //Control signal input - 3 bits per channel
    input [29:0] ctrl;

    //3-bit output for each channel
    output [2:0] chan_1;
    output [2:0] chan_2;
    output [2:0] chan_3;
    output [2:0] chan_4;
    output [2:0] chan_5;
    output [2:0] chan_6;
    output [2:0] chan_7;
    output [2:0] chan_8;
    output [2:0] chan_9;
    output [2:0] chan_10;

    reg [2:0] chan_1;
    reg [2:0] chan_2;
    reg [2:0] chan_3;
    reg [2:0] chan_4;
    reg [2:0] chan_5;
    reg [2:0] chan_6;
    reg [2:0] chan_7;
    reg [2:0] chan_8;
    reg [2:0] chan_9;
    reg [2:0] chan_10;

    wire [2:0] ad_passthrough;
    wire [2:0] buf_1;
    wire [2:0] buf_2;
    wire [2:0] buf_3;
    wire [2:0] buf_4;
    wire [29:0] ctrl;

    always @( ctrl or ad_passthrough or buf_1 or buf_2 or buf_3 or buf_4 )
    begin
        
        //1 case for each channel output
    
        case( ctrl[2:0] )
            3'b000: chan_1 = buf_1;
            3'b001: chan_1 = buf_2;
            3'b010: chan_1 = buf_3;
            3'b011: chan_1 = buf_4;
            3'b1xx: chan_1 = ad_passthrough;
            default: chan_1 = ad_passthrough;
        endcase
        
        case( ctrl[5:3] )
            3'b000: chan_2 = buf_1;
            3'b001: chan_2 = buf_2;
            3'b010: chan_2 = buf_3;
            3'b011: chan_2 = buf_4;
            3'b1xx: chan_2 = ad_passthrough;
            default: chan_2 = ad_passthrough;
        endcase
        
        case( ctrl[8:6] )
            3'b000: chan_3 = buf_1;
            3'b001: chan_3 = buf_2;
            3'b010: chan_3 = buf_3;
            3'b011: chan_3 = buf_4;
            3'b1xx: chan_3 = ad_passthrough;
            default: chan_3 = ad_passthrough;
        endcase
        
        case( ctrl[11:9] )
            3'b000: chan_4 = buf_1;
            3'b001: chan_4 = buf_2;
            3'b010: chan_4 = buf_3;
            3'b011: chan_4 = buf_4;
            3'b1xx: chan_4 = ad_passthrough;
            default: chan_4 = ad_passthrough;
        endcase
        
        case( ctrl[14:12] )
            3'b000: chan_5 = buf_1;
            3'b001: chan_5 = buf_2;
            3'b010: chan_5 = buf_3;
            3'b011: chan_5 = buf_4;
            3'b1xx: chan_5 = ad_passthrough;
            default: chan_5 = ad_passthrough;
        endcase
        
        case( ctrl[17:15] )
            3'b000: chan_6 = buf_1;
            3'b001: chan_6 = buf_2;
            3'b010: chan_6 = buf_3;
            3'b011: chan_6 = buf_4;
            3'b1xx: chan_6 = ad_passthrough;
            default: chan_6 = ad_passthrough;
        endcase
        
        case( ctrl[20:18] )
            3'b000: chan_7 = buf_1;
            3'b001: chan_7 = buf_2;
            3'b010: chan_7 = buf_3;
            3'b011: chan_7 = buf_4;
            3'b1xx: chan_7 = ad_passthrough;
            default: chan_7 = ad_passthrough;
        endcase
        
        case( ctrl[23:21] )
            3'b000: chan_8 = buf_1;
            3'b001: chan_8 = buf_2;
            3'b010: chan_8 = buf_3;
            3'b011: chan_8 = buf_4;
            3'b1xx: chan_8 = ad_passthrough;
            default: chan_8 = ad_passthrough;
        endcase
        
        case( ctrl[26:24] )
            3'b000: chan_9 = buf_1;
            3'b001: chan_9 = buf_2;
            3'b010: chan_9 = buf_3;
            3'b011: chan_9 = buf_4;
            3'b1xx: chan_9 = ad_passthrough;
            default: chan_9 = ad_passthrough;
        endcase
        
        case( ctrl[29:27] )
            3'b000: chan_10 = buf_1;
            3'b001: chan_10 = buf_2;
            3'b010: chan_10 = buf_3;
            3'b011: chan_10 = buf_4;
            3'b1xx: chan_10 = ad_passthrough;
            default: chan_10 = ad_passthrough;
        endcase
        
    end

endmodule
        