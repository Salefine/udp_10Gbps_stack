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
//   Description:  arp receive module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/20     myj          1.0         Original
//  2020/12/9     myj          1.1         When request arp is valid, then arp_valid assert
//********************************************************************************/


module arp_rx(
		//rx axis interface from frame rx module
		input                           rx_axis_aclk,
		input                           rx_axis_areset,
		input [63:0]       	     		frame_rx_axis_tdata,
        input [7:0]     	     		frame_rx_axis_tkeep,
        input                           frame_rx_axis_tvalid,		 
        input                           frame_rx_axis_tlast,
        input                          	frame_rx_axis_tusr,	
		
		input [47:0]					local_mac_addr,				//local mac address, defined by user
		input [31:0]					local_ip_addr,				//local ip address, defined by user
		output reg                		arp_reply_req,           	//arp reply request to arp tx module
		input 	           				arp_reply_ack,           	//arp reply ack from arp tx module 
		output reg						arp_valid,					//after checked, arp reply is valid			
		output reg [31:0]				arp_rcvd_src_ip_addr,		//received source ip address, can be used to arp cache
		output reg [47:0]				arp_rcvd_src_mac_addr,		//received source mac address, can be used to arp cache
		input [31:0]					dst_ip_addr					//destination ip address, defined by user
    );


localparam ARP_REQUEST_CODE = 16'h0001 ;	//arp request code parameter
localparam ARP_REPLY_CODE   = 16'h0002 ;	//arp reply code parameter

reg [15:0]					rcvd_op ;				//received operation code, 1 means arp request, 2 means arp reply
reg [31:0]					arp_rcvd_src_ip_addr ;	//received source ip address
reg [31:0]					rcvd_dst_ip_addr ;		//received destination ip address
reg [47:0]					rcvd_dst_mac_addr ;		//received destination mac address

reg [31:0]					timeout ;	//timeout counter
	
/* axis rx statement */		
localparam ARP_RCV_WORD_1ST      	= 9'b000000001 ;	//receive first word
localparam ARP_RCV_WORD_2ND      	= 9'b000000010 ;	//receive second word
localparam ARP_RCV_WORD_3RD      	= 9'b000000100 ;	//receive third word
localparam ARP_RCV_WORD_4TH      	= 9'b000001000 ;	//receive fourth word
localparam ARP_RCV_WORD_DATA    	= 9'b000010000 ;	//receive dummy data
localparam ARP_RCV_GOOD     		= 9'b000100000 ;	//check if received frame is good by tusr signal, if tusr high, it is good frame, or bad frame
localparam ARP_RCV_BAD     			= 9'b001000000 ;	//check if received frame is good by tusr signal, if tusr high, it is good frame, or bad frame
localparam ARP_RCV_REQUEST     		= 9'b010000000 ;	//if recevied code is request, then send reply request signal to arp tx module
localparam ARP_RCV_REPLY     		= 9'b100000000 ;	//recevied code is reply


reg [8:0]    rcv_state  ;
reg [8:0]    rcv_next_state ;



always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcv_state  <=  ARP_RCV_WORD_1ST  ;
    else
      rcv_state  <= rcv_next_state ;
  end
  
always @(*)
  begin
    case(rcv_state)
      ARP_RCV_WORD_1ST            :
        begin
          if (frame_rx_axis_tvalid & ~frame_rx_axis_tlast)
            rcv_next_state <= ARP_RCV_WORD_2ND ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= ARP_RCV_BAD ;
          else
            rcv_next_state <= ARP_RCV_WORD_1ST ;
        end		
	  ARP_RCV_WORD_2ND   :
		begin
          if (frame_rx_axis_tvalid & ~frame_rx_axis_tlast)
            rcv_next_state <= ARP_RCV_WORD_3RD ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= ARP_RCV_BAD ;
          else
            rcv_next_state <= ARP_RCV_WORD_2ND ;
        end		
	  ARP_RCV_WORD_3RD   :
		begin
          if (frame_rx_axis_tvalid & ~frame_rx_axis_tlast)
            rcv_next_state <= ARP_RCV_WORD_4TH ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= ARP_RCV_BAD ;
          else
            rcv_next_state <= ARP_RCV_WORD_3RD ;
        end		
	  ARP_RCV_WORD_4TH   :
		begin
          if (frame_rx_axis_tvalid & ~frame_rx_axis_tlast)
            rcv_next_state <= ARP_RCV_WORD_DATA ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast & frame_rx_axis_tusr)
			rcv_next_state <= ARP_RCV_GOOD ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast & ~frame_rx_axis_tusr)
			rcv_next_state <= ARP_RCV_BAD ;
          else
            rcv_next_state <= ARP_RCV_WORD_4TH ;
        end		
	  ARP_RCV_WORD_DATA     :
        begin
          if (frame_rx_axis_tvalid & frame_rx_axis_tlast & frame_rx_axis_tusr)
            rcv_next_state <= ARP_RCV_GOOD ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast & ~frame_rx_axis_tusr)
            rcv_next_state <= ARP_RCV_BAD ;
          else
            rcv_next_state <= ARP_RCV_WORD_DATA ; 	
        end
	  ARP_RCV_GOOD      :
		begin
		/* check if received code is reqeust code and received destination ip address equals to local ip address 
			and received source ip address equals to destination ip address, then state switch to request state */
		  if (rcvd_op == ARP_REQUEST_CODE && rcvd_dst_ip_addr == local_ip_addr && arp_rcvd_src_ip_addr == dst_ip_addr)		
			rcv_next_state <= ARP_RCV_REQUEST ;
		/* check if received code is reply code and received destination ip address equals to local ip address 
			and destination mac address equals to local mac address and received source ip address equals to destination ip address, 
			then state switch to reply state */
		  else if (rcvd_op == ARP_REPLY_CODE && rcvd_dst_ip_addr == local_ip_addr && rcvd_dst_mac_addr == local_mac_addr && arp_rcvd_src_ip_addr == dst_ip_addr)
			rcv_next_state <= ARP_RCV_REPLY ;	
		  else
			rcv_next_state <= ARP_RCV_WORD_1ST ;
		end	
	  ARP_RCV_BAD     :
        rcv_next_state <= ARP_RCV_WORD_1ST ;
	  ARP_RCV_REQUEST :
		begin
			if (arp_reply_ack)	//check arp reply acknowledge from arp tx module
				rcv_next_state <= ARP_RCV_WORD_1ST ;
			else if (timeout == 32'd1000000)
				rcv_next_state <= ARP_RCV_WORD_1ST ;
			else
				rcv_next_state <= ARP_RCV_REQUEST ;
		end
	  ARP_RCV_REPLY : 
		rcv_next_state <= ARP_RCV_WORD_1ST ;
      default        :
        rcv_next_state <= ARP_RCV_WORD_1ST ;
    endcase
  end  	
/* timeout counter in request state */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
		timeout <= 32'd0 ;
	else if (rcv_state == ARP_RCV_REQUEST)
		timeout <= timeout + 1 ;
	else
		timeout <= 32'd0 ;
  end


/* received ARP op */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
      rcvd_op  <=  16'd0  ;
	end
    else if (rcv_state == ARP_RCV_WORD_1ST && frame_rx_axis_tvalid)
	begin
      rcvd_op[15:8]  <=  frame_rx_axis_tdata[55:48]  ;
	  rcvd_op[7:0]  <=  frame_rx_axis_tdata[63:56]  ;
	end
  end	
/* received source mac and ip address */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
	  arp_rcvd_src_mac_addr <= 48'd0 ;	  
      arp_rcvd_src_ip_addr  <= 32'd0  ;
	end
    else if (rcv_state == ARP_RCV_WORD_2ND && frame_rx_axis_tvalid)
	begin
      arp_rcvd_src_mac_addr[47:40]  <=  frame_rx_axis_tdata[7:0]  ;
	  arp_rcvd_src_mac_addr[39:32]  <=  frame_rx_axis_tdata[15:8]  ;
	  arp_rcvd_src_mac_addr[31:24]  <=  frame_rx_axis_tdata[23:16]  ;
	  arp_rcvd_src_mac_addr[23:16]  <=  frame_rx_axis_tdata[31:24]  ;
	  arp_rcvd_src_mac_addr[15:8]  	<=  frame_rx_axis_tdata[39:32]  ;
	  arp_rcvd_src_mac_addr[7:0]  	<=  frame_rx_axis_tdata[47:40]  ;
	  arp_rcvd_src_ip_addr[31:24]  	<=  frame_rx_axis_tdata[55:48]  ;
	  arp_rcvd_src_ip_addr[23:16]  	<=  frame_rx_axis_tdata[63:56]  ;
	end
	else if (rcv_state == ARP_RCV_WORD_3RD && frame_rx_axis_tvalid)
	begin
	  arp_rcvd_src_ip_addr[15:8]  	<=  frame_rx_axis_tdata[7:0]  ;
	  arp_rcvd_src_ip_addr[7:0]  	<=  frame_rx_axis_tdata[15:8]  ;
	end
  end	
/* received destination mac and ip address */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
	  rcvd_dst_mac_addr <= 48'd0 ;	  
      rcvd_dst_ip_addr  <= 32'd0  ;
	end
    else if (rcv_state == ARP_RCV_WORD_3RD && frame_rx_axis_tvalid)
	begin
      rcvd_dst_mac_addr[47:40]  <=  frame_rx_axis_tdata[23:16] 	;
	  rcvd_dst_mac_addr[39:32]  <=  frame_rx_axis_tdata[31:24] 	;
	  rcvd_dst_mac_addr[31:24]  <=  frame_rx_axis_tdata[39:32]  ;
	  rcvd_dst_mac_addr[23:16]  <=  frame_rx_axis_tdata[47:40]  ;
	  rcvd_dst_mac_addr[15:8]  	<=  frame_rx_axis_tdata[55:48]  ;
	  rcvd_dst_mac_addr[7:0]  	<=  frame_rx_axis_tdata[63:56]  ;
	end
	else if (rcv_state == ARP_RCV_WORD_4TH && frame_rx_axis_tvalid)
	begin
	  rcvd_dst_ip_addr[31:24]  	<=  frame_rx_axis_tdata[7:0]    ;
	  rcvd_dst_ip_addr[23:16]  	<=  frame_rx_axis_tdata[15:8]   ;
	  rcvd_dst_ip_addr[15:8]  	<=  frame_rx_axis_tdata[23:16]  ;
	  rcvd_dst_ip_addr[7:0]  	<=  frame_rx_axis_tdata[31:24]  ;
	end
  end

/* reply request to arp tx module */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      arp_reply_req  <=  1'b0  ;
    else if (rcv_state == ARP_RCV_REQUEST)
	  arp_reply_req <= 1'b1 ;
	else if (arp_reply_ack)
	  arp_reply_req <= 1'b0 ;
	else if (rcv_state == ARP_RCV_WORD_1ST)
	  arp_reply_req <= 1'b0 ;
  end

/* arp is valid in reply state, user can record received source ip address and mac address in arp cache */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      arp_valid  <=  1'b0  ;
    else if (rcv_state == ARP_RCV_REPLY)
	  arp_valid  <=  1'b1  ;
	else if (rcv_state == ARP_RCV_REQUEST)
	  arp_valid  <=  1'b1  ;
	else 
	  arp_valid  <= 1'b0 ;
  end

	
endmodule



// IP Decryptor end

