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
//   Description:  sync fifo module
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/
module sync_fifo
#(
  parameter WIDTH = 8 ,
  parameter DEPTH = 8 
)
(
  input                   clk ,
  input                   rst_n,
  input                   wren,		//write enable
  input                   rden,		//read enable
  input      [WIDTH-1:0]  data,		//data in
  output     [WIDTH-1:0]  q,		//data out
  output reg              full,		//fifo full
  output reg              empty,	//fifo empty
  output reg 			  almost_full //fifo almost full
) ;

reg [DEPTH-1:0]  waddr  ;	//write address
reg [DEPTH-1:0]  raddr  ;	//read address


/* When write enable and fifo not full, write address plus 1 */
always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
    waddr <= {DEPTH{1'b0}} ;
  else if (wren & ~full)
    waddr <= waddr + 1'b1 ;
end
/* When read enable and fifo not empty, read address plus 1 */ 
always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
    raddr <= {DEPTH{1'b0}} ;
  else if (rden & ~empty)
    raddr <= raddr + 1'b1 ;
end

/* full signal control */
always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
    full <=  1'b0 ;
  else if ((wren & ~rden) && ((waddr == raddr - 1) || ((raddr == {DEPTH{1'b0}}) && waddr == 2**DEPTH - 1)))
    full <=  1'b1 ;
  else if (full & rden)
    full <=  1'b0 ;
end
/* almost full signal control */
always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
    almost_full <=  1'b0 ;
  else if ((wren & ~rden) && ((waddr == raddr - 2) || ((raddr ==  {DEPTH{1'b0}}) && waddr == 2**DEPTH - 2) || ((raddr == 1) && waddr == 2**DEPTH - 1)))
    almost_full <=  1'b1 ;
  else if (~full & rden & ~wren)
    almost_full <=  1'b0 ;
end


/* empty signal control */
always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
    empty <=  1'b1 ;
  else if ((rden & ~wren) && ((raddr == waddr - 1) || ((waddr == {DEPTH{1'b0}}) && raddr == 2**DEPTH - 1)))
    empty <=  1'b1 ;
  else if (empty & wren)
    empty <=  1'b0 ;
end


/* Instantiate dual port ram module */
dpram 
#(
	.WIDTH(WIDTH),
	.DEPTH(DEPTH),
	.LATENCY(1)
)
dpram_std
( 
	.clock		(clk),
	.rst_n		(rst_n),
	.din		(data),
	.wraddress	(waddr),
	.rdaddress	(raddr),
	.wren		(wren),
	.rden		(rden),
	.dout  		(q)
);



endmodule




// IP Decryptor end

