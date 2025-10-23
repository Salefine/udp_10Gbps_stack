//This example file is for demonstration purpose only. Users must not use this keyfile to encrypt their sources. 
//It is strongly recommonded that users create their own key file to use for encrypting their sources. 


// IP Decryptor begin

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//  Author: myj   myj@alinx.com                                                 //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//     WEB: http://www.alinx.cn/                                                //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Copyright (c) 2019,ALINX(shanghai) Technology Co.,Ltd                        //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
//   Description:  dpram module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/
module dpram
       #(
         parameter WIDTH = 8,
         parameter DEPTH = 10,
		 parameter LATENCY = 1
       )
       ( input                   clock,
		 input					 rst_n,
         input    [WIDTH-1:0]    din,
         input    [DEPTH-1:0]    wraddress,
         input    [DEPTH-1:0]    rdaddress,
         input                   wren,
		 input					 rden,
         output   [WIDTH-1:0]    dout
       );
       
reg [WIDTH-1:0] ram[2**DEPTH-1:0];   //declare ram
reg [WIDTH-1:0] ram_data ;

always @ (posedge clock)
  begin
	
    if (wren)                	   //write data to ram
      ram[wraddress] <= din;	  
	  
	if (~rst_n)
	  ram_data <= {WIDTH{1'b0}} ;  //clear data value
	else if (rden)				   //read ram data
      ram_data <= ram[rdaddress] ;
  end
 
  
generate
    if (LATENCY == 1) 			//if latency equals to 1, only one output register
	begin: no_output_register  
		assign dout = ram_data ;
	end
	else 
	begin: output_register
		reg [WIDTH-1:0] dout_reg ;	
		always @(posedge clock)
		begin
		  if (~rst_n)
			dout_reg <= {WIDTH{1'b0}} ;
		  else
			dout_reg <= ram_data;
		end
		assign dout = dout_reg;
	end
endgenerate

endmodule



// IP Decryptor end

