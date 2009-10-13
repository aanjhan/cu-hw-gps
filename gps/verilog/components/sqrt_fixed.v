`include "global.vh"
`include "sqrt_fixed.vh"

//`define DEBUG
`include "debug.vh"

//Calculate sqrt(x).

module sqrt_fixed(
    input clk,
    input reset,
    input input_ready,
    input [`SQRT_INPUT_RANGE] in,
    output wire flag_new_input,
    output reg output_ready,
    output reg in_use,
    output reg [`SQRT_OUTPUT_RANGE] out
    );

    /********************** Reg and wire declarations ***********************/

    // Post-padded input.  The final output y of the module is sqrt(x).
    wire [`SQRT_INPUT_PADDED_RANGE] in_padded;
    
    /* Logic output wires (Logic evaluated in wires for readability later on) */
    wire [`SQRT_ROOT_RANGE]   root1_lshift_1;            //root1 << 1
    wire [`SQRT_REM_RANGE]    rem1_lshift_WIDTH_m_SHIFT; //rem1 << (WIDTH - SHIFT)
    wire [`SQRT_INPUT_PADDED_RANGE]  x1_lshift_2;               //x1 << 2
    wire [`SQRT_INPUT_PADDED_RANGE]  x1_rshift_SHIFT_full;      //x1 >> SHIFT
    wire [`SQRT_REM_RANGE]    x1_rshift_SHIFT;           //x1 >> SHIFT truncated to rem range
    wire [`SQRT_ROOT_RANGE]   root2_lshift_1;            //root2 << 1
    wire [`SQRT_ROOT_RANGE]   root2_rshift_SHIFT_DIV_2;  //root2 >> (SHIFT / 2)
    wire [`SQRT_ROOT_RANGE]   root_mux_in_0;             //Input0 to root mux
    wire [`SQRT_ROOT_RANGE]   root_mux_in_1;             //Input1 to root mux
    wire [`SQRT_ROOT_RANGE]   root_mux_out;              //Output of root mux
    wire [`SQRT_REM_RANGE]    rem_mux_in_0;              //Input0 to rem mux
    wire [`SQRT_REM_RANGE]    rem_mux_in_1;              //Input 1 to rem mux
    wire [`SQRT_REM_RANGE]    rem_mux_out;               //Output of rem mux
    wire                      comparator_out;            //Output of divisor <= rem2
    wire [`SQRT_REM_RANGE]    divisor;                   // (rem2 << 1) + 1

    
    /* Variable registers.  <name>1 is the first stage of the pipeline,
    * <name2> is the second. */

    `PRESERVE reg [`SQRT_INPUT_PADDED_RANGE] x1;
    `PRESERVE reg [`SQRT_INPUT_PADDED_RANGE] x2;
    `PRESERVE reg [`SQRT_REM_RANGE]   rem1;
    `PRESERVE reg [`SQRT_REM_RANGE]   rem2;
    `PRESERVE reg [`SQRT_REM_RANGE]   rem_m_div;
    `PRESERVE reg [`SQRT_ROOT_RANGE]  root1;
    `PRESERVE reg [`SQRT_ROOT_RANGE]  root2;
    `PRESERVE reg [`SQRT_ROOT_RANGE]  root2_p1;
    `PRESERVE reg                     comp_out_pl;

    /* Loop counter register */
    `PRESERVE reg [`SQRT_LOOPCOUNTER_RANGE] loopcounter;

    /************************* Wire assignments *****************************/
    
    //Concatenate SQRT_INPUT_PAD zeros to the left side of the input.
    assign in_padded = {{`SQRT_INPUT_PAD{1'b0}},in};

    //Assign shift wires
    assign root1_lshift_1 = root1 << 1;
    assign rem1_lshift_WIDTH_m_SHIFT = rem1 << `SQRT_WIDTH_M_SHIFT;
    assign x1_lshift_2 = x1 << 2;
    assign x1_rshift_SHIFT_full = x1 >> `SQRT_SHIFT;
    assign x1_rshift_SHIFT = x1_rshift_SHIFT_full[`SQRT_REM_RANGE];
    assign root2_lshift_1 = root1_lshift_1 << 1;
    assign root2_rshift_SHIFT_DIV_2 = root2 >> `SQRT_SHIFT_DIV_BY_2;
    assign root_mux_in_0 = root2;
    assign root_mux_in_1 = root2_p1;
    assign root_mux_out = comparator_out ? root_mux_in_1 : root_mux_in_0;
    assign rem_mux_in_0 = rem2;
    assign rem_mux_in_1 = rem_m_div;
    assign rem_mux_out = comparator_out ? rem_mux_in_1 : rem_mux_in_0;
    assign comparator_out = comp_out_pl;
    assign divisor = root2_lshift_1[`SQRT_REM_RANGE] + `SQRT_REM_WIDTH'b1;

    //New input flag (prevents one request from trampling another)
    assign flag_new_input = input_ready & !in_use;

    /*********************** Reg updates ************************************/
    always @ (posedge clk) begin

        // Update loop counter.  Loop counter initializes to
        // LOOPCOUNTER_MAX_VALUE on reset or flag_new_input high.
        // Loop counter decrements by 1 when flag_new_input high, or when its value 
        // is neither zero nor LOOPCOUNTER_MAX_VALUE.
        loopcounter <= reset ? `SQRT_LOOPCOUNTER_MAX_VALUE :                                        //Reset to max
                       (flag_new_input && loopcounter == `SQRT_LOOPCOUNTER_MAX_VALUE) ? loopcounter - `SQRT_LOOPCOUNTER_WIDTH'b1 : //Decrement on flag_new_input_high
                       (flag_new_input && loopcounter == `SQRT_LOOPCOUNTER_WIDTH'b0) ? `SQRT_LOOPCOUNTER_MAX_VALUE_M1 : 
                       (loopcounter == `SQRT_LOOPCOUNTER_MAX_VALUE) ? loopcounter :
                       (loopcounter == `SQRT_LOOPCOUNTER_WIDTH'b0) ? `SQRT_LOOPCOUNTER_WIDTH'b0 :   //If at zero, remain at zero
                       loopcounter - `SQRT_LOOPCOUNTER_WIDTH'b1;                                    //Decrement otherwise
        
        //Update x1.  x1 resets to zero.  x1 gets new value in_padded if
        //flag_new_input is high, in_use is zero, and gets x2 otherwise.
        x1 <= reset ? `SQRT_INPUT_PADDED_WIDTH'b0 :            //Reset to zero
              (input_ready && !in_use) ? in_padded :    //If flag_new_input, get new input value
              x2;                                       //Otherwise, get new value from x2

        //Update rem1.  rem1 resets to zero.  rem1 gets the output of rem_mux.
        rem1 <= reset ? `SQRT_REM_WIDTH'b0 :     //Reset to zero
                rem_mux_out;                     //Take the output of rem_mux otherwise

        //Update root1.  root1 resets to zero.  root1 gets the output of
        //root_mux.
        root1 <= reset ? `SQRT_ROOT_WIDTH'b0 :   //Reset to zero
                 root_mux_out;                   //Take the output of rem_mux otherwise

        //Update x2.  x2 resets to zero.  x2 gets the output of (x << 2)
        //& (2^width - 1).
        x2 <= reset ? `SQRT_INPUT_PADDED_WIDTH'b0 :     //Reset to zero
              x1_lshift_2;       //Take (x1 << 2) & 2^WIDTH - 1 otherwise

        //Update rem2.  rem2 resets to zero.  rem2 gets the output of rem1 <<
        //(WIDTH - SHIFT) | x1 >> SHIFT
        rem2 <= reset ? `SQRT_REM_WIDTH'b0 :     //Reset to zero
                rem1_lshift_WIDTH_m_SHIFT | x1_rshift_SHIFT; //Take the logic output otherwise

        //Update rem_m_div.  rem_m_div resets to zero.  rem_m_div gets the
        //output of rem1 << (WIDTH - SHIFT) | x1 >> SHIFT - DIVISOR
        rem_m_div <= reset ? `SQRT_REM_WIDTH'b0 : //Reset to zero
                (rem1_lshift_WIDTH_m_SHIFT | x1_rshift_SHIFT) - divisor; //Take the logic output otherwise     

        //Update comp_out_pl.   
        comp_out_pl <= reset ? 1'b0 : (divisor <= (rem1_lshift_WIDTH_m_SHIFT | x1_rshift_SHIFT));

        //Update root2.  root2 resets to zero.  root2 gets root1 << 1
        root2 <= reset ? `SQRT_ROOT_WIDTH'b0 :   //Reset to zero
                 root1_lshift_1;                 //Take the output of root1 << 1 otherwise

        //Update root2_p1.  root2_p1 resets to zero.  
        //root2_p1 gets (root1 << 1) + 1
        root2_p1 <= reset ? `SQRT_ROOT_WIDTH'b0 : //reset to zero
                    root1_lshift_1  + `SQRT_ROOT_WIDTH'b1; //Take the output of (root1 << 1) + 1 otherwise

        //Update the output out. out resets to zero.  Out gets 
        //root >> (SHIFT/2).
        out <= reset ? `SQRT_OUTPUT_WIDTH'b0 :   //Reset to zero
               root2_rshift_SHIFT_DIV_2[`SQRT_OUTPUT_RANGE];         //Take the output of root >> (SHIFT/2) otherwise

        //Update output_ready.  output_ready resets to zero.  output_ready is
        //set to zero if loopcounter = 1 and zero otherwise.
        output_ready <= reset ? 1'b0 :  //Reset to zero
                        (loopcounter == `SQRT_LOOPCOUNTER_WIDTH'b1) ? 1'b1 : 
                        1'b0; //Set to one if loopcounter = 1, 
                              //set to zero otherwise
                              
        //Update in_use.  in_use resets to zero.  in_use is set to 1 if
        //loopcounter is counting down.
        in_use <= reset ? 1'b0 : 
                  input_ready || (in_use && loopcounter != `SQRT_LOOPCOUNTER_WIDTH'b0);

    end
    
endmodule

