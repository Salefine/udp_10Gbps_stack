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
//   Description:  frame receive module
//				   receive steam data from mac
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/


module frame_rx
	#(
		parameter StreamWidth = 64
	)
	(	
		input                            	     rx_axis_aclk,
		input                            	     rx_axis_areset,
		//rx axis interface from mac rx module
        input  [StreamWidth-1:0]       	     	 mac_rx_axis_tdata,
        input  [StreamWidth/8-1:0]     	     	 mac_rx_axis_tkeep,
        input                            	     mac_rx_axis_tvalid,		 
        input                            	     mac_rx_axis_tlast,
        input                           	     mac_rx_axis_tusr,
		//axis interface to next layer, arp or ip layer
		output  [StreamWidth-1:0]       	     frame_rx_axis_tdata,
        output reg [StreamWidth/8-1:0]     	     frame_rx_axis_tkeep,
        output reg                           	 frame_rx_axis_tvalid,		 
        output reg                           	 frame_rx_axis_tlast,
        output reg                          	 frame_rx_axis_tusr,
		
		
		input	[47:0]							 local_mac_addr,	//local mac address, defined by user
		output reg  [47:0]						 rcvd_dst_mac_addr,	//received destination mac address
		output reg  [47:0]						 rcvd_src_mac_addr,	//received destination mac address
		output reg  [15:0]						 rcvd_type			//received type, 0800: IP, 0806: ARP
		
		

    );


reg  [63:0]					rcvd_data;		//received data word
reg  [63:0]					rcvd_data_dly;	//received data word register
wire [63:0]					valid_data ;	//valid data except ethernet head
reg							frame_valid ;	//frame valid signal


/* axis rx statement */	

localparam MAC_RCV_ADDR         = 5'b00001 ;	//receive mac address
localparam MAC_RCV_ADDR_LT      = 5'b00010 ;	//receive mac address and length/type
localparam MAC_RCV_DATA         = 5'b00100 ;	//receive data
localparam MAC_RCV_GOOD     	= 5'b01000 ;	//receive good frame
localparam MAC_RCV_BAD     		= 5'b10000 ;	//receive bad frame



reg [4:0]    rcv_state  ;
reg [4:0]    rcv_next_state ;



always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcv_state  <=  MAC_RCV_ADDR  ;
    else
      rcv_state  <= rcv_next_state ;
  end
  
always @(*)
  begin
    case(rcv_state)
      MAC_RCV_ADDR            :
        begin
          if (mac_rx_axis_tvalid & ~mac_rx_axis_tlast)
            rcv_next_state <= MAC_RCV_ADDR_LT ;
		  else if (mac_rx_axis_tvalid & mac_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= MAC_RCV_BAD ;
          else
            rcv_next_state <= MAC_RCV_ADDR ;
        end		
	  MAC_RCV_ADDR_LT   :
		begin
          if (mac_rx_axis_tvalid & ~mac_rx_axis_tlast)
            rcv_next_state <= MAC_RCV_DATA ;
		  else if (mac_rx_axis_tvalid & mac_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= MAC_RCV_BAD ;
          else
            rcv_next_state <= MAC_RCV_ADDR_LT ;
        end		
	  MAC_RCV_DATA     :
        begin
          if (mac_rx_axis_tvalid & mac_rx_axis_tlast & mac_rx_axis_tusr)
            rcv_next_state <= MAC_RCV_GOOD ;
		  else if (mac_rx_axis_tvalid & mac_rx_axis_tlast & ~mac_rx_axis_tusr)
            rcv_next_state <= MAC_RCV_BAD ;
          else
            rcv_next_state <= MAC_RCV_DATA ; 	
        end
	  MAC_RCV_GOOD      :
        rcv_next_state <= MAC_RCV_ADDR ;
	  MAC_RCV_BAD     :
        rcv_next_state <= MAC_RCV_ADDR ;
      default        :
        rcv_next_state <= MAC_RCV_ADDR ;
    endcase
  end  

/* received destination mac address */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcvd_dst_mac_addr  <=  48'd0  ;
    else if (rcv_state == MAC_RCV_ADDR && mac_rx_axis_tvalid)
	begin
      rcvd_dst_mac_addr[47:40]  <= mac_rx_axis_tdata[7:0]  ;
	  rcvd_dst_mac_addr[39:32]  <= mac_rx_axis_tdata[15:8] ;
	  rcvd_dst_mac_addr[31:24]  <= mac_rx_axis_tdata[23:16] ;
	  rcvd_dst_mac_addr[23:16]  <= mac_rx_axis_tdata[31:24] ;
	  rcvd_dst_mac_addr[15:8]   <= mac_rx_axis_tdata[39:32] ;
	  rcvd_dst_mac_addr[7:0]    <= mac_rx_axis_tdata[47:40] ;
	end
  end
/* if received destination mac address equals to local mac address or boardcast mac address, frame is valid */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      frame_valid  <=  1'b0  ;
    else if (rcvd_dst_mac_addr == local_mac_addr || rcvd_dst_mac_addr == 48'hff_ff_ff_ff_ff_ff)
      frame_valid  <=  1'b1 ;
	else 
	  frame_valid  <=  1'b0  ;
  end  

/* received source mac address */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcvd_src_mac_addr  <=  48'd0  ;
    else if (rcv_state == MAC_RCV_ADDR && mac_rx_axis_tvalid)
	begin
	  rcvd_src_mac_addr[47:40]  <= mac_rx_axis_tdata[55:48] ;
	  rcvd_src_mac_addr[39:32]  <= mac_rx_axis_tdata[63:56] ;
	end
	else if (rcv_state == MAC_RCV_ADDR_LT && mac_rx_axis_tvalid)
	begin
	  rcvd_src_mac_addr[31:24]  <= mac_rx_axis_tdata[7:0]   ;
	  rcvd_src_mac_addr[23:16]  <= mac_rx_axis_tdata[15:8]  ;
	  rcvd_src_mac_addr[15:8]   <= mac_rx_axis_tdata[23:16] ;
	  rcvd_src_mac_addr[7:0]    <= mac_rx_axis_tdata[31:24] ;
	end
  end	
/* received type */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcvd_type  <=  16'd0  ;
    else if (rcv_state == MAC_RCV_ADDR_LT && mac_rx_axis_tvalid)
	begin   
	  rcvd_type[15:8]  <= mac_rx_axis_tdata[39:32] ;
	  rcvd_type[7:0]  <= mac_rx_axis_tdata[47:40] ;	  
	end
  end	
/* received data */  
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcvd_data  <=  64'd0  ;
    else if (rcv_state == MAC_RCV_ADDR_LT && mac_rx_axis_tvalid)
      rcvd_data[15:0]  <= mac_rx_axis_tdata[63:48] ;
	else if (rcv_state == MAC_RCV_DATA && mac_rx_axis_tvalid)
	begin
      rcvd_data[63:16]  <= mac_rx_axis_tdata[47:0] ;
	  rcvd_data[15:0]  <= mac_rx_axis_tdata[63:48] ;
	end
  end	
/* received data delay */ 
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcvd_data_dly  <=  64'd0  ;
    else if (rcv_state == MAC_RCV_DATA || rcv_state == MAC_RCV_GOOD || rcv_state == MAC_RCV_BAD)
      rcvd_data_dly  <= rcvd_data ;
  end	
/* combine valid data */ 
assign valid_data = {rcvd_data[63:16], rcvd_data_dly[15:0]} ;




/**************************************************************
frame rx storage 
**************************************************************/
reg  [7:0]				mac_rx_axis_tkeep_dly ;
reg						mac_rx_axis_tusr_dly ;


assign frame_rx_axis_tdata = valid_data ;
/* mac tkeep and tusr register */ 
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
      mac_rx_axis_tkeep_dly  <=  8'd0  ;
	  mac_rx_axis_tusr_dly <= 1'b0 ;
	end
    else 
	begin
      mac_rx_axis_tkeep_dly  <= mac_rx_axis_tkeep ;
	  mac_rx_axis_tusr_dly <= mac_rx_axis_tusr ;
	end
  end
/* frame tvalid control, if received destination mac address not equals to loacl mac address and all 1'b1, tvalid is false, 
	or if mac tkeep delay is 7f or ff, which means there is additinal one word in the last */ 
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
		frame_rx_axis_tvalid  <=  1'b0  ;
	else if (rcvd_dst_mac_addr != local_mac_addr && rcvd_dst_mac_addr != 48'hff_ff_ff_ff_ff_ff)
		frame_rx_axis_tvalid  <=  1'b0  ;
    else if (rcv_state == MAC_RCV_DATA && mac_rx_axis_tvalid)
		frame_rx_axis_tvalid  <= 1'b1 ;
	else if (rcv_state == MAC_RCV_GOOD || rcv_state == MAC_RCV_BAD)
	begin
		if (mac_rx_axis_tkeep_dly == 8'h7f || mac_rx_axis_tkeep_dly == 8'hff)
			frame_rx_axis_tvalid  <= 1'b1 ;
		else
			frame_rx_axis_tvalid  <= 1'b0 ;
	end
	else
		frame_rx_axis_tvalid  <= 1'b0 ;
  end	
/* frame tlast, tusr, tkeep control, if received destination mac address not equals to loacl mac address and all 1'b1, they are false */ 
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		frame_rx_axis_tlast  <=  1'b0  ;
		frame_rx_axis_tusr   <= 1'b0 ;
		frame_rx_axis_tkeep  <= 8'h00 ;
	end
	else if (rcvd_dst_mac_addr != local_mac_addr && rcvd_dst_mac_addr != 48'hff_ff_ff_ff_ff_ff)
	begin
		frame_rx_axis_tlast  <=  1'b0  ;
		frame_rx_axis_tusr   <= 1'b0 ;
		frame_rx_axis_tkeep  <= 8'h00 ;
	end
	else if (rcv_state == MAC_RCV_DATA && rcv_state == rcv_next_state)
	begin
		frame_rx_axis_tlast  <= 1'b0 ;
		frame_rx_axis_tusr   <= 1'b0 ;
		frame_rx_axis_tkeep  <= 8'hff ;
	end
    else if (rcv_state == MAC_RCV_DATA && rcv_state != rcv_next_state)
	begin
		if (mac_rx_axis_tkeep == 8'h7f || mac_rx_axis_tkeep == 8'hff)
		begin
			frame_rx_axis_tlast  <= 1'b0 ;
			frame_rx_axis_tusr   <= 1'b0 ;
			frame_rx_axis_tkeep  <= 8'hff ;
		end
		else
		begin
			frame_rx_axis_tlast  <= 1'b1 ;
			frame_rx_axis_tusr   <= mac_rx_axis_tusr ;
			frame_rx_axis_tkeep  <= {mac_rx_axis_tkeep[5:0],2'b11} ;
		end
	end
	else if (rcv_state == MAC_RCV_GOOD || rcv_state == MAC_RCV_BAD)
	begin
		if (frame_rx_axis_tlast)
		begin
			frame_rx_axis_tlast  <= 1'b0 ;
			frame_rx_axis_tusr   <= 1'b0 ;
			frame_rx_axis_tkeep  <= 8'h00 ;
		end
		else
		begin
			frame_rx_axis_tlast  <= 1'b1 ;
			frame_rx_axis_tusr   <= mac_rx_axis_tusr_dly ;
			frame_rx_axis_tkeep  <= mac_rx_axis_tkeep_dly>>6 ;
		end
	end
	else
	begin
		frame_rx_axis_tlast  <= 1'b0 ;
		frame_rx_axis_tusr   <= 1'b0 ;
		frame_rx_axis_tkeep  <= 8'h00 ;
	end
  end	




	
endmodule



// IP Decryptor end

