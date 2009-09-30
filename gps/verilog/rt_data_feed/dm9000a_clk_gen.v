module dm9000a_clk_gen(
    input      clk,
    output reg clk_enet);

   //Generate 25MHz Ethernet controller clock from
   //incoming clock, assuming 50MHz.
   always @(posedge clk) begin
      clk_enet <= ~clk_enet;
   end
   
endmodule