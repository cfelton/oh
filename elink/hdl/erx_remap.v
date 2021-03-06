module erx_remap (/*AUTOARG*/
   // Outputs
   emesh_access_out, emesh_packet_out,
   // Inputs
   clk, reset, emesh_access_in, emesh_packet_in, remap_mode,
   remap_sel, remap_pattern, remap_base, remap_bypass, rx_rd_wait,
   rx_wr_wait
   );

   parameter AW = 32;
   parameter DW = 32;
   parameter PW = 104;
   parameter ID = 12'h808;
   
   //Clock/reset
   input clk;
   input reset;
   
   //Input from arbiter
   input          emesh_access_in;
   input [PW-1:0] emesh_packet_in;
   
   //Configuration
   input [1:0] 	  remap_mode;    //00=none,01=static,02=continuity
   input [11:0]   remap_sel;     //number of bits to remap
   input [11:0]   remap_pattern; //static pattern to map to
   input [31:0]   remap_base;    //remap offset
   input 	  remap_bypass;  //dynamic bypass (read request | link match)
   
   //Output to TX IO   
   output 	   emesh_access_out;
   output [PW-1:0] emesh_packet_out;

   //Wait
   input 	   rx_rd_wait;
   input 	   rx_wr_wait;

   wire [31:0] 	   static_remap;
   wire [31:0] 	   dynamic_remap;
   wire [31:0] 	   remap_mux;
   wire 	   write_in;
   wire [31:0] 	   addr_in;
   wire [31:0] 	   addr_out;
   reg 		   emesh_access_out;
   reg [PW-1:0]    emesh_packet_out;

   //TODO:FIX!
   parameter[5:0]  colid = ID[5:0];
   
   //parsing packet
   assign addr_in[31:0]  =  emesh_packet_in[39:8];
   assign write_in       =  emesh_packet_in[1];
   
   //simple static remap
   assign static_remap[31:20] = (remap_sel[11:0] & remap_pattern[11:0]) |
			        (~remap_sel[11:0] & addr_in[31:20]);

   assign static_remap[19:0]  = addr_in[19:0];
    
   //more complex compresssed map
   assign dynamic_remap[31:0] = addr_in[31:0]      //input
			     - (colid << 20)    //subtracing elink (start at 0)
			     + remap_base[31:0]  //adding back base
                             - (addr_in[31:26]<<$clog2(colid));
     			     

   wire 	   remap_en = ~(remap_mode[1:0]==2'b00);
   
   assign remap_mux[31:0]  = (remap_bypass | ~remap_en)  ? addr_in[31:0] :
			     (remap_mode[1:0]==2'b01)    ? static_remap[31:0] :
	  		                                   dynamic_remap[31:0];
      
   always @ (posedge clk)
     if (reset)
       begin
	  emesh_access_out         <= 'b0;
       end
     else if((write_in & ~rx_wr_wait) | (~write_in & ~rx_rd_wait))    
       begin
	  emesh_access_out         <= emesh_access_in;
	  emesh_packet_out[PW-1:0] <= {emesh_packet_in[103:40],
                                       remap_mux[31:0],
                                       emesh_packet_in[7:0]
				       };
       end
   
endmodule // etx_mux

