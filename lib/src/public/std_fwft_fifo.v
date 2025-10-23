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
//   Description:  standard and fwft fifo module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/
module std_fwft_fifo
#(
  parameter WIDTH = 8 ,			//This is width
  parameter DEPTH = 8 ,   		//This is depth
  parameter FIFO_TYPE = "std"   //std or fwft
)
(
  input                  	clk ,
  input                  	rst_n,
  input                  	wren,
  input                  	rden,
  input   [WIDTH-1:0] 		data,
  output  [WIDTH-1:0] 		q,
  output              		full,
  output              		empty,
  output					almost_full
) ;

wire   	fifo_rd_en	;
wire 	fifo_empty 	;
reg 	dout_valid 	;
/* Generate fwft or standard fifo controller */
generate
	if (FIFO_TYPE == "fwft")
	begin : fwft_mode
		assign fifo_rd_en = !fifo_empty && (!dout_valid || rden);
		assign empty = !dout_valid;
		
		always @(posedge clk)
		if (~rst_n)
			dout_valid <= 0;
		else
			begin
				if (fifo_rd_en)
					dout_valid <= 1;
				else if (rden)
					dout_valid <= 0;
			end 
	end
	else
	begin
		assign fifo_rd_en = rden ;
		assign empty = fifo_empty ;
	end
endgenerate

/* Instantiate basic synchronous fifo */
sync_fifo
#(
  .WIDTH(WIDTH) ,
  .DEPTH(DEPTH) 
)
fifo_inst
(
  .clk 				(clk 	),
  .rst_n			(rst_n	),
  .wren				(wren	),
  .rden				(fifo_rd_en	),
  .data				(data	),
  .q				(q		),
  .full				(full	),
  .empty			(fifo_empty	),
  .almost_full  	(almost_full)  
) ;

endmodule




// IP Decryptor end

