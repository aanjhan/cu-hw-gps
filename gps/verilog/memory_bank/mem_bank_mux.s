`include "../components/global.vh"

module mem_bank_mux(
    ctrl,
    ad_passthrough,
<? for i in range(1,`NUM_BANKS+1):
    print("    buf_" + `i` + ",\n")
?>
<? for i in range(1,`NUM_CHANNELS+1):
    if i < `NUM_CHANNELS:
        print("    chan_" + `i` + ",\n")
    else:
        print("    chan_" + `i` + "\n")
?>
);

    //Data inputs from the direct A/D passthrough and the data buffers
    input [<?print(``INPUT_WIDTH-1`)?>:0] ad_passthrough;
<? for i in range(1,`NUM_BANKS+1):
    print("    input [" + ``INPUT_WIDTH-1` + ":0] buf_" + `i` + ";\n")
?>

//Control signal input - 3 bits per channel
<? h = 3 * `NUM_CHANNELS - 1
print("    input [" + `h` + ":0] ctrl;\n")
?>

//3-bit output for each channel
<? h = `INPUT_WIDTH-1
for i in range(1,`NUM_CHANNELS+1):
    print("    output [" + `h` + ":0] chan_" + `i` + ";\n")
?>

<? h = `INPUT_WIDTH-1
for i in range(1,`NUM_CHANNELS+1):
    print("    reg [" + `h` + ":0] chan_" + `i` + ";\n")
?>
    
<? h = `INPUT_WIDTH-1
print("    wire [" + `h` + ":0] ad_passthrough;\n")
for i in range(1,`NUM_BANKS+1):
    print("    wire [" + `h` + ":0] buf_" + `i` + ";\n")
print("    wire [" + `3 * `NUM_CHANNELS - 1` + ":0] ctrl;\n")
?>

always @( ctrl or ad_passthrough <?
for i in range(1,`NUM_BANKS+1):
    print("or buf_" + `i` + " ")
?>)
    begin

    // 1 case for each channel output
<?
N = len(d2b(`NUM_BANKS))
for i in range(1,`NUM_CHANNELS + 1):
    print("        case( ctrl [" + `(3 * i - 1)` + ":0] )\n")
    for j in range(1,`NUM_BANKS + 1):
        print("            "+`N`+"'b"+d2b(j-1).rjust(N,'0') + ": chan_" + `i` + " = buf_" + `j` + ";\n")
    print("            "+`N`+"'b"+d2b(`NUM_BANKS).rjust(N,`0`) + ": chan_" + `i` + " = ad_passthrough;\n")
    print("            default: chan_" + `i` + " = ad_passthrough;\n")
    print("        endcase\n\n")
?>
    end

endmodule
