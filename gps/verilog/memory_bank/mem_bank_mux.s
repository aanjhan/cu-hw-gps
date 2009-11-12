`include "../components/global.vh"

module mem_bank_mux(

    //Control signal input - 3 bits per channel
<?
ctrl_width = 3 * `NUM_CHANNELS - 1;
print("input [%s:%s] ctrl," % (`ctrl_width`,'0'));
?>

    //Data inputs from the direct A/D passthrough and the data buffers
<?
print("input [%s:%s] ad_passthrough," % ('`INPUT_WIDTH-1','0'))

for i in range(1,`NUM_BANKS+1):
    print("input [`INPUT_WIDTH-1:0] buf_%s," % `i`)
?>

    //Sample-width output for each channel
<?
for i in range(1,`NUM_CHANNELS+1):
    if i < `NUM_CHANNELS:
        print("output reg [`INPUT_WIDTH-1:0] chan_%s," % `i`)
    else:
        print("output reg [`INPUT_WIDTH-1:0] chan_%s;" % `i`)
?>
);

always @( ctrl or ad_passthrough
<?
for i in range(1,`NUM_BANKS+1):
    print("or buf_" + `i` + " ")
?>) begin

    // 1 case for each channel output
<?
N = len(d2b(`NUM_BANKS))
numbanks = `NUM_BANKS
for i in range(1,`NUM_CHANNELS + 1):
    print("case( ctrl [" + `(3 * i - 1)` + ":0] )", "\n")
    for j in range(1,`NUM_BANKS + 1):
        print(""+`N`+"'b"+d2b(j-1).rjust(N,'0') + ": chan_" + `i` + " = buf_" + `j` + ";", "\n")
    print(""+`N`+"'b"+d2b(numbanks).rjust(N,'0') + ": chan_" + `i` + " = ad_passthrough;", "\n")
    print("default: chan_" + `i` + " = ad_passthrough;", "\n")
    print("endcase\n\n")
?>

end

endmodule
