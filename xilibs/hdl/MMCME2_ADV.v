module MMCME2_ADV # (
		     parameter BANDWIDTH = "OPTIMIZED",
		     parameter real CLKFBOUT_MULT_F = 5.000,
		     parameter real CLKFBOUT_PHASE = 0.000,
		     parameter CLKFBOUT_USE_FINE_PS = "FALSE",
		     parameter real CLKIN1_PERIOD = 10.000,
		     parameter real CLKIN2_PERIOD = 0.000,
		     parameter real CLKOUT0_DIVIDE_F = 1.000,
		     parameter real CLKOUT0_DUTY_CYCLE = 0.500,
		     parameter real CLKOUT0_PHASE = 0.000,
		     parameter CLKOUT0_USE_FINE_PS = "FALSE",
		     parameter integer CLKOUT1_DIVIDE = 1,
		     parameter real CLKOUT1_DUTY_CYCLE = 0.500,
		     parameter real CLKOUT1_PHASE = 0.000,
		     parameter CLKOUT1_USE_FINE_PS = "FALSE",
		     parameter integer CLKOUT2_DIVIDE = 1,
		     parameter real CLKOUT2_DUTY_CYCLE = 0.500,
		     parameter real CLKOUT2_PHASE = 0.000,
		     parameter CLKOUT2_USE_FINE_PS = "FALSE",
		     parameter integer CLKOUT3_DIVIDE = 1,
		     parameter real CLKOUT3_DUTY_CYCLE = 0.500,
		     parameter real CLKOUT3_PHASE = 0.000,
		     parameter CLKOUT3_USE_FINE_PS = "FALSE",
		     parameter CLKOUT4_CASCADE = "FALSE",
		     parameter integer CLKOUT4_DIVIDE = 1,
		     parameter real CLKOUT4_DUTY_CYCLE = 0.500,
		     parameter real CLKOUT4_PHASE = 0.000,
		     parameter CLKOUT4_USE_FINE_PS = "FALSE",
		     parameter integer CLKOUT5_DIVIDE = 1,
		     parameter real CLKOUT5_DUTY_CYCLE = 0.500,
		     parameter real CLKOUT5_PHASE = 0.000,
		     parameter CLKOUT5_USE_FINE_PS = "FALSE",
		     parameter integer CLKOUT6_DIVIDE = 1,
		     parameter real CLKOUT6_DUTY_CYCLE = 0.500,
		     parameter real CLKOUT6_PHASE = 0.000,
		     parameter CLKOUT6_USE_FINE_PS = "FALSE",
		     parameter COMPENSATION = "ZHOLD",
		     parameter integer DIVCLK_DIVIDE = 1,
		     parameter [0:0] IS_CLKINSEL_INVERTED = 1'b0,
		     parameter [0:0] IS_PSEN_INVERTED = 1'b0,
		     parameter [0:0] IS_PSINCDEC_INVERTED = 1'b0,
		     parameter [0:0] IS_PWRDWN_INVERTED = 1'b0,
		     parameter [0:0] IS_RST_INVERTED = 1'b0,
		     parameter real REF_JITTER1 = 0.010,
		     parameter real REF_JITTER2 = 0.010,
		     parameter SS_EN = "FALSE",
		     parameter SS_MODE = "CENTER_HIGH",
		     parameter integer SS_MOD_PERIOD = 10000,
		     parameter STARTUP_WAIT = "FALSE"
		     )(

  output 	CLKFBOUT,     //feedback clock to connect to CLKFBIN
  output 	CLKFBOUTB,    //inverted feedback clock output
  output 	CLKFBSTOPPED, //indicates that FB clock as stoppped
  output 	CLKINSTOPPED, //indicates that input clock has stopped
  output 	CLKOUT0,      //clock output
  output 	CLKOUT0B,     //inverted clock output
  output 	CLKOUT1,
  output 	CLKOUT1B,
  output 	CLKOUT2,
  output 	CLKOUT2B,
  output 	CLKOUT3,
  output 	CLKOUT3B,
  output 	CLKOUT4,
  output 	CLKOUT5,
  output 	CLKOUT6,
  output 	LOCKED,       //indicates PLL is locked
  output 	PSDONE,       //phase shift done
  input 	CLKFBIN,
  input 	CLKIN1,
  input 	CLKIN2,
  input 	CLKINSEL,    //selects between two input clocks,1=primary
  output 	DRDY,        //dynamic reconfig ready
  input [6:0] 	DADDR,       //Address port for dynamic reconfig
  input 	DCLK,        //clock port for dynamic reconfig
  input 	DEN,         //enable for dynamic reconfig
  input [15:0] 	DI,          //data for dynamic reconfig
  input 	DWE,         //dynamic reconfig write enable
  output [15:0] DO,          //readback data for dyanmic reconfig
  input 	PSCLK,       //phase shift clock
  input 	PSEN,        //phase shift enable
  input 	PSINCDEC,    //phase shift decrement/increment  
  input 	PWRDWN,      //global power down pin
  input 	RST          //async global reset   
);

  //#LOCAL DERIVED PARAMETERS
 parameter VCO_PERIOD = (CLKIN1_PERIOD * DIVCLK_DIVIDE) / CLKFBOUT_MULT_F;
 parameter CLK0_DELAY = VCO_PERIOD * CLKOUT0_DIVIDE_F * (CLKOUT0_PHASE/360);
 parameter CLK1_DELAY = VCO_PERIOD * CLKOUT1_DIVIDE * (CLKOUT1_PHASE/360);
 parameter CLK2_DELAY = VCO_PERIOD * CLKOUT2_DIVIDE * (CLKOUT2_PHASE/360);
 parameter CLK3_DELAY = VCO_PERIOD * CLKOUT3_DIVIDE * (CLKOUT3_PHASE/360);
 parameter CLK4_DELAY = VCO_PERIOD * CLKOUT4_DIVIDE * (CLKOUT4_PHASE/360);
 parameter CLK5_DELAY = VCO_PERIOD * CLKOUT5_DIVIDE * (CLKOUT5_PHASE/360);
 parameter CLK6_DELAY = VCO_PERIOD * CLKOUT6_DIVIDE * (CLKOUT6_PHASE/360);
      
   //##############
   //#VCO 
   //##############
   reg 	  vco_clk = 1'b0;
   always
     #(VCO_PERIOD/2) vco_clk = ~vco_clk;

   //##############
   //#DIVIDERS
   //##############
   wire [3:0] DIVCFG[6:0]; 
   wire [6:0] CLKOUT_DIV;
      
   assign DIVCFG[0] = $clog2(CLKOUT0_DIVIDE_F);
   assign DIVCFG[1] = $clog2(CLKOUT1_DIVIDE);
   assign DIVCFG[2] = $clog2(CLKOUT2_DIVIDE);
   assign DIVCFG[3] = $clog2(CLKOUT3_DIVIDE);
   assign DIVCFG[4] = $clog2(CLKOUT4_DIVIDE);
   assign DIVCFG[5] = $clog2(CLKOUT5_DIVIDE);
   assign DIVCFG[6] = $clog2(CLKOUT6_DIVIDE);

   //ugly POR reset
   reg 	      POR;
   initial
     begin
	POR=1'b1;
	#1
	POR=1'b0;	
     end

   //BUG! This only supports divide by 2,4,8, etc for now
   //TODO: This clearly won't work, need general purpose clock divider
   //divide by 2-N (3,5,6,7 and all the other ugly numbers)
   genvar i;
   generate for(i=0; i<7; i=i+1)
     begin : gen_clkdiv
	clock_divider clkdiv (/*AUTOINST*/
			      // Outputs
			      .clkout		(CLKOUT_DIV[i]),
			      // Inputs
			      .clkin		(vco_clk),
			      .divcfg		(DIVCFG[i]),
			      .reset		(RST | POR));		
     end      
   endgenerate

   //##############
   //#PHASE DELAY
   //##############
   reg CLKOUT0;
   reg CLKOUT1;
   reg CLKOUT2;
   reg CLKOUT3;
   reg CLKOUT4;
   reg CLKOUT5;
   reg CLKOUT6;
   
   always @ (CLKOUT_DIV)
     begin	
	CLKOUT0 <= #(CLK0_DELAY) CLKOUT_DIV[0];
	CLKOUT1 <= #(CLK1_DELAY) CLKOUT_DIV[1];
	CLKOUT2 <= #(CLK2_DELAY) CLKOUT_DIV[2];
	CLKOUT3 <= #(CLK3_DELAY) CLKOUT_DIV[3];
	CLKOUT4 <= #(CLK4_DELAY) CLKOUT_DIV[4];
	CLKOUT5 <= #(CLK5_DELAY) CLKOUT_DIV[5];
	CLKOUT6 <= #(CLK6_DELAY) CLKOUT_DIV[6];
     end

   //##############
   //#DUMMY DRIVES
   //##############
   assign CLKFBOUT=CLKIN1;
   
   //###########################
   //#SANITY CHECK LOCK COUNTER
   //############################
   parameter LCW=4;   
   reg [LCW-1:0] lock_counter;
   wire 	 reset = POR | RST;   
   
   always @ (posedge CLKIN1 or posedge reset)
     if(reset)
       lock_counter[LCW-1:0]  <= {(LCW){1'b1}};
     else if(~LOCKED)
       lock_counter[LCW-1:0] <= lock_counter[LCW-1:0] - 1'b1;

   assign LOCKED = ~(|lock_counter[LCW-1:0]);
   
endmodule // MMCME2_ADV
// Local Variables:
// verilog-library-directories:("." "../../common/hdl")
// End:
