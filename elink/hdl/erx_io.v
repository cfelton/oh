module erx_io (/*AUTOARG*/
   // Outputs
   rx_clk_pll, rxo_wr_wait_p, rxo_wr_wait_n, rxo_rd_wait_p,
   rxo_rd_wait_n, rx_access, rx_burst, rx_packet,
   // Inputs
   reset, rx_lclk, rx_lclk_div4, rxi_lclk_p, rxi_lclk_n, rxi_frame_p,
   rxi_frame_n, rxi_data_p, rxi_data_n, rx_wr_wait, rx_rd_wait
   );

   parameter IOSTANDARD = "LVDS_25";
   parameter PW = 104;

   //#########################
   //# reset, clocks
   //#########################
   input       reset;                       // reset
   input       rx_lclk;                     // fast I/O clock
   input       rx_lclk_div4;                // slow clock
   output      rx_clk_pll;                  // clock output for pll
   
   //##########################
   //# elink pins
   //##########################
   input       rxi_lclk_p,   rxi_lclk_n;    // rx clock input
   input       rxi_frame_p,  rxi_frame_n;   // rx frame signal
   input [7:0] rxi_data_p,   rxi_data_n;    // rx data
   output      rxo_wr_wait_p,rxo_wr_wait_n; // rx write pushback output
   output      rxo_rd_wait_p,rxo_rd_wait_n; // rx read pushback output
  
   //##########################
   //# erx logic interface
   //##########################
   output 	   rx_access;
   output 	   rx_burst;
   output [PW-1:0] rx_packet;
   input           rx_wr_wait;
   input           rx_rd_wait;

   //############
   //# WIRES
   //############
   wire [7:0]    rxi_data;         // High-speed serial data
   wire          rxi_frame;        // serial frame
   wire 	 access_wide;
   reg 		 valid_packet;
   wire [15:0]   data_in;

   //############
   //# REGS
   //############
   reg [7:0] 	 data_even_reg;   
   reg [7:0] 	 data_odd_reg;
   reg  	 rx_frame;
   reg  	 rx_frame_old;
   reg [111:0]   rx_sample; 
   reg [6:0] 	 rx_pointer; //7 cycles
   reg 		 access;  
   reg 		 burst;
   reg [PW-1:0]  rx_packet_lclk;
   reg 		 rx_access;
   reg [PW-1:0]  rx_packet;
   reg 		 rx_burst;


   
   //################################
   //# Input Buffers Instantiation
   //################################

   IBUFDS
	 #(.DIFF_TERM  ("TRUE"),
       .IOSTANDARD (IOSTANDARD))
	 ibuf_data[7:0]
	   (.I     (rxi_data_p[7:0]),
            .IB    (rxi_data_n[7:0]),
            .O     (rxi_data[7:0]));
   
   IBUFDS
	 #(.DIFF_TERM  ("TRUE"), 
       .IOSTANDARD (IOSTANDARD))
	 ibuf_frame
	   (.I     (rxi_frame_p),
            .IB    (rxi_frame_n),
            .O     (rxi_frame));

   IBUFDS
	 #(.DIFF_TERM  ("TRUE"), 
       .IOSTANDARD (IOSTANDARD))
	 ibuf_lclk
	   (.I     (rxi_lclk_p),
            .IB    (rxi_lclk_n),
            .O     (rx_clk_pll)
	    );
   
   //#####################
   //# FRAME EDGE DETECTOR
   //#####################       

   always @ (posedge rx_lclk or posedge reset)
     if(reset)
       begin
	  rx_frame     <= 1'b0;
	  rx_frame_old <= rx_frame;	  
       end
     else
       begin
	  rx_frame     <= rxi_frame;
	  rx_frame_old <= rx_frame;	  
       end
       
   assign new_tran = rx_frame & ~rx_frame_old;

   //#####################
   //# DDR SAMPLERS
   //#####################

   //odd bytes
   always @ (posedge rx_lclk)
     data_even_reg[7:0] <= rxi_data[7:0];

   //odd bytes
   always @ (negedge rx_lclk)
     data_odd_reg[7:0] <= rxi_data[7:0];

   assign data_in[15:0] = {data_odd_reg[7:0],data_even_reg[7:0]};

   //#####################
   //#CREATE 112 BIT PACKET 
   //#####################
   
   //write Pointer   
   always @ (posedge rx_lclk)
     if (~rx_frame)
       rx_pointer[6:0]<=7'b0000001; //new frame
     else if (rx_pointer[6])
       rx_pointer[6:0]<=7'b0001000; //anticipate burst
     else if(rx_frame)
       rx_pointer[6:0]<={rx_pointer[5:0],1'b0};//middle of frame
      
   //convert to 112 bit packet
   always @ (posedge rx_lclk)
     if(rx_frame)   
       begin
	  if(rx_pointer[0])
	    rx_sample[15:0]    <= data_in[15:0];
	  if(rx_pointer[1])
	    rx_sample[31:16]   <= data_in[15:0];
	  if(rx_pointer[2])
	    rx_sample[47:32]   <= data_in[15:0];
	  if(rx_pointer[3])
	    rx_sample[63:48]   <= data_in[15:0];
	  if(rx_pointer[4])
	    rx_sample[79:64]   <= data_in[15:0];
	  if(rx_pointer[5])
	    rx_sample[95:80]   <= data_in[15:0];
	  if(rx_pointer[6])
	    rx_sample[111:96]  <= data_in[15:0];	  
       end
/*
       case(rx_pointer[7:0])
	 8'b0000001: rx_sample[15:0]   <= data_in[15:0];
	 8'b0000010: rx_sample[31:16]  <= data_in[15:0];
	 8'b0000100: rx_sample[47:32]  <= data_in[15:0];
	 8'b0001000: rx_sample[63:48]  <= data_in[15:0];
	 8'b0010000: rx_sample[79:64]  <= data_in[15:0];
	 8'b0100000: rx_sample[95:80]  <= data_in[15:0];
       	 8'b1000000: rx_sample[111:96] <= data_in[15:0];
	 default: rx_sample[111:0] <= 'b0;
       endcase // case (rx_pointer)
*/
   
   //#####################  
   //#DATA VALID SIGNAL 
   //#####################
   always @ (posedge rx_lclk)
     begin     
	access       <= rx_pointer[6];
	valid_packet <= access;//data pipeline
     end
     
   //###################################
   //#SAMPLE AND HOLD DATA
   //###################################

   //(..and shuffle data for 104 bit packet)
   always @ (posedge rx_lclk)
     if(access)   
       begin
	  //access
	  burst                   <= rx_frame;	    //burst detected (for next cycle)
	  rx_packet_lclk[0]     <= rx_sample[40];
	  //write
	  rx_packet_lclk[1]     <= rx_sample[41];
	  //datamode
	  rx_packet_lclk[3:2]   <= rx_sample[43:42];
	  //ctrlmode
	  rx_packet_lclk[7:4]   <= rx_sample[15:12];
	  //dstaddr
	  rx_packet_lclk[39:8]  <= {rx_sample[11:8],
			             rx_sample[23:16],
			             rx_sample[31:24],
			             rx_sample[39:32],
			             rx_sample[47:44]};
	  //data
	  rx_packet_lclk[71:40] <= {rx_sample[55:48],
			              rx_sample[63:56],
			              rx_sample[71:64],
			              rx_sample[79:72]};	
	  //srcaddr
	  rx_packet_lclk[103:72]<= {rx_sample[87:80],
			              rx_sample[95:88],
			              rx_sample[103:96],
			              rx_sample[111:104]
				      };	
     end

   //###################################
   //#SYNCHRONIZE TO SLOW CLK
   //###################################
 
   //stretch access pulse to 4 cycles
   pulse_stretcher #(.DW(3)) ps0 (.out			(access_wide),
				 .in			(valid_packet),
				 .clk			(rx_lclk),
				 .reset			(reset)
				 );


   always @ (posedge rx_lclk_div4)
     rx_access <= access_wide;
   
   always @ (posedge rx_lclk_div4)
     if(access_wide)
       begin
	  rx_packet[PW-1:0] <= rx_packet_lclk[PW-1:0];
	  rx_burst          <= burst;
       end
  
   //#####################################
   //# Wait signals (asynchronous)
   //#####################################

   OBUFDS 
     #(
       .IOSTANDARD(IOSTANDARD),
       .SLEW("SLOW")
       ) OBUFDS_RXWRWAIT
       (
        .O(rxo_wr_wait_p),
        .OB(rxo_wr_wait_n),
        .I(rx_wr_wait)
        );
   
   OBUFDS 
     #(
       .IOSTANDARD(IOSTANDARD),
       .SLEW("SLOW")
       ) OBUFDS_RXRDWAIT
       (
        .O(rxo_rd_wait_p),
        .OB(rxo_rd_wait_n),
        .I(rx_rd_wait)
        );

endmodule // erx_io
// Local Variables:
// verilog-library-directories:("." "../../emesh/hdl" "../../common/hdl")
// End:

/*
 Copyright (C) 2014 Adapteva, Inc.
 Contributed by Andreas Olofsson <fred@adapteva.com>
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program (see the file COPYING).  If not, see
 <http://www.gnu.org/licenses/>.
*/
