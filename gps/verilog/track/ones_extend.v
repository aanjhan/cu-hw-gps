module OnesExtend(
    input [(IN_WIDTH-1):0] value,
    output wire [(OUT_WIDTH-1):0] result);
   parameter IN_WIDTH = 2;
   parameter OUT_WIDTH = 2;

   //Determine input sign.
   wire sign;
   assign sign = value[IN_WIDTH-1];

   //Convert input to two's complement.
   wire [(IN_WIDTH-1):0] value2c;
   assign value2c = sign ? -{1'b0,value[(IN_WIDTH-2):0]} : {1'b0,value[(IN_WIDTH-2):0]};

   //Sign-extend to output.
   assign result[(IN_WIDTH-1):0] = value2c;
   assign result[(OUT_WIDTH-1):(IN_WIDTH)] = {(OUT_WIDTH-IN_WIDTH){value2c[sign]}};
endmodule