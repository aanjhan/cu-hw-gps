module OnesExtend(
    input [(IN_WIDTH-1):0] value,
    output wire [(OUT_WIDTH-1):0] result);
   parameter IN_WIDTH = 2;
   parameter OUT_WIDTH = 2;

   //Determine magnitude.
   wire [(IN_WIDTH-2):0] mag;
   assign mag = value [(IN_WIDTH-2):0];

   wire zero;
   assign zero = mag=='h0;

   //Determine input sign.
   wire sign;
   assign sign = zero ? 0 : value[IN_WIDTH-1];

   //Convert input to two's complement.
   wire [(IN_WIDTH-1):0] value2c;
   assign value2c = zero ? 'h0 :
                    sign ? -mag :
                    mag;

   //Sign-extend to output.
   assign result[(IN_WIDTH-1):0] = value2c;
   assign result[(OUT_WIDTH-1):(IN_WIDTH)] = {(OUT_WIDTH-IN_WIDTH){sign}};
endmodule