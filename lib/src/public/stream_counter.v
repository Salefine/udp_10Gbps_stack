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
//   Description:  stream counter record module
//				   Record how many words in one frame
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/
module stream_counter
       (        
				
		 input                			axis_aclk,
         input                			axis_areset,  
		 /* axis interface */
		 input  [63:0]        			axis_tdata,
         input  [7:0]     	  			axis_tkeep,
         input                			axis_tvalid,		 
         input                			axis_tlast,
         input 	           				axis_tready,
					
		 output reg [15:0]    			stream_byte_len,	//how many bytes in one frame
		 output reg [15:0]     			stream_word_len		//how many words in one frame, 1 word = 8 bytes
       ) ;
 
 reg [3:0]				last_count ;		//how many bytes in the last word
 reg [15:0]				stream_byte_cnt ;	//byte counter
 reg [15:0]				stream_word_cnt ;	//word counter
 
/* Record data length from stream */
always @(posedge axis_aclk)
  begin
    if (~axis_areset)
	begin
      stream_byte_cnt <= 16'd0 ;
	  stream_byte_len <= 16'd0 ;
	  stream_word_cnt <= 16'd0 ;
	  stream_word_len <= 16'd0 ;
	end
    else if (axis_tvalid & axis_tready)
	begin
		if (axis_tlast)
		begin
			stream_byte_len <= stream_byte_cnt + last_count ;
			stream_byte_cnt <= 16'd0 ;
			stream_word_cnt <= 16'd0 ;
			stream_word_len <= stream_word_cnt + 1'b1 ;
		end
		else
		begin
			stream_byte_cnt <= stream_byte_cnt + 8  ;
			stream_word_cnt <= stream_word_cnt + 1'b1 ;
		end
	end
  end
/* decode byte counter for last stream data  */
always @(*)
  begin
	case(axis_tkeep)
		8'b0000_0001: last_count <= 4'd1 ;
		8'b0000_0011: last_count <= 4'd2 ;
		8'b0000_0111: last_count <= 4'd3 ;
		8'b0000_1111: last_count <= 4'd4 ;
		8'b0001_1111: last_count <= 4'd5 ;
		8'b0011_1111: last_count <= 4'd6 ;
		8'b0111_1111: last_count <= 4'd7 ;
		8'b1111_1111: last_count <= 4'd8 ;
		default : last_count <= 4'd0 ;
	endcase
  end
  
endmodule



// IP Decryptor end

