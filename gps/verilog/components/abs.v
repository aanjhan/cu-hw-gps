module abs(
    input [(WIDTH-1):0] in,
    output wire [(WIDTH-2):0] out);

   parameter WIDTH = 1;

   (* keep *) wire negative;
   assign negative = in[WIDTH-1];

   (* keep *) wire [(WIDTH-2):0] m_in;
   assign m_in = (~in[(WIDTH-2):0]) + {{(WIDTH-2){1'b0}},1'b1};
   
   assign out = negative ?
                m_in :
                in[(WIDTH-2):0];
endmodule