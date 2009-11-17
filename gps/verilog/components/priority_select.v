module priority_select(
    input [(NUM_ENTRIES-1):0]       eligible,
    output wire [(NUM_ENTRIES-1):0] select_oh);

   parameter NUM_ENTRIES = 1;

   wire [(NUM_ENTRIES-1):0] prev_sel;
   
   genvar i;
   generate
      for(i=0;i<NUM_ENTRIES;i=i+1) begin : sel_gen
         if(i==0) begin
            assign prev_sel[i] = 1'b0;
            assign select_oh[i] = eligible[i];
         end
         else begin
            assign prev_sel[i] = prev_sel[i-1] || select_oh[i-1];
            assign select_oh[i] = eligible[i] && !prev_sel[i];
         end
      end
   endgenerate
   
endmodule