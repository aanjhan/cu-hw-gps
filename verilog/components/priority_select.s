// This file is part of the Cornell University Hardware GPS Receiver Project.
// Copyright (C) 2009 - Adam Shapiro (ams348@cornell.edu)
//                      Tom Chatt (tjc42@cornell.edu)
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
module priority_select(
    input [(NUM_ENTRIES-1):0]       eligible,
    output reg [1:0]                select,
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

   //FIXME Finish use directive and make NUM_ENTRIES a parameter,
   //FIXME and calculate select bit-range from that.
   //FIXME Fix spacing for the code generated below.
<? NUM_ENTRIES=2;
print("always @(eligible) begin");
print("casez(eligible)");
for i in range(0,NUM_ENTRIES):
  case_value=(NUM_ENTRIES-i-1)*"z" + "1" + i*"0";
  print("%d'b%s: select <= %d'd%d;" % (NUM_ENTRIES,case_value,2,i));
print("default: select <= %d'd0;" % (2));
print("endcase");
print("end");
?>
   
endmodule