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
//   Description:  This module is used to send arp data when request arp or reply arp
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/

module arp_tx
	#(
		parameter StreamWidth = 64
	)
    (                    
     input  [47:0]        					 dst_mac_addr   , 			//destination mac address
     input  [47:0]        					 src_mac_addr   , 			//source mac address, defined by user
     input  [31:0]        					 src_ip_addr    , 			//source ip address, defined by user
     input  [31:0]        					 dst_ip_addr    , 			//destination ip address, defined by user   

     input                					 arp_request_req,         	//arp request
	 output reg            					 arp_request_ack,         	//arp request ack
	 input                					 arp_reply_req,           	//arp reply request from arp rx module
     output reg           					 arp_reply_ack,           	//arp reply ack to arp rx module     
	 

	 output reg								 arp_not_empty,				//arp is ready to transmit axi stream
	 
	 input                            	     tx_axis_aclk,
     input                            	     tx_axis_areset,	
	 /* arp tx axis interface */
     output reg [StreamWidth-1:0]       	 arp_tx_axis_tdata,
     output reg [StreamWidth/8-1:0]     	 arp_tx_axis_tkeep,
     output reg                           	 arp_tx_axis_tvalid,		 
     output reg                           	 arp_tx_axis_tlast,
     input                           	     arp_tx_axis_tready

    ) ;
       
localparam mac_type         = 16'h0806 ;
localparam hardware_type    = 16'h0001 ;
localparam protocol_type    = 16'h0800 ;
localparam mac_length       = 8'h06    ;
localparam ip_length        = 8'h04    ;

localparam ARP_REQUEST_CODE = 16'h0001 ;
localparam ARP_REPLY_CODE   = 16'h0002 ;


reg  [15:0]        op ;					//arp operation code
reg  [31:0]        arp_dst_ip_addr ;	//arp destination ip address
reg  [47:0]        arp_dst_mac_addr  ;	//arp destination mac address
reg  [31:0]		   timeout ;			//timeout counter
/* arp tx statement */	
localparam IDLE             		= 9'b000000001 ;
localparam ARP_REQUEST_WAIT 		= 9'b000000010 ;
localparam ARP_REPLY_WAIT 			= 9'b000000100 ;
localparam ARP_DATA_0 				= 9'b000001000 ;
localparam ARP_DATA_1   			= 9'b000010000 ;
localparam ARP_DATA_2				= 9'b000100000 ;
localparam ARP_DATA_3   			= 9'b001000000 ;
localparam ARP_TIMEOUT				= 9'b010000000 ;
localparam ARP_END					= 9'b100000000 ;

reg [8:0]    state  ;
reg [8:0]    next_state ;

always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      state  <=  IDLE  ;
    else
      state  <= next_state ;
  end
  
always @(*)
  begin
    case(state)
      IDLE             :
        begin
          if (arp_request_req)					//arp request
            next_state <= ARP_REQUEST_WAIT ;
          else if (arp_reply_req)				//arp reply
            next_state <= ARP_REPLY_WAIT  ;
          else
            next_state <= IDLE ;
        end
	  ARP_REQUEST_WAIT :						//wait state, for register latch
            next_state <= ARP_DATA_0     ;
	  ARP_REPLY_WAIT   :
            next_state <= ARP_DATA_0     ;
			
	  ARP_DATA_0 :
		begin
			if (arp_tx_axis_tready & arp_tx_axis_tvalid)
				next_state <= ARP_DATA_1     ;
			else if (timeout == 32'd999_999)			//if there is no stream, then timeout, goto timeout state
				next_state <= ARP_TIMEOUT     ;
			else
				next_state <= ARP_DATA_0     ;
		end
	  ARP_DATA_1 :
		begin
			if (arp_tx_axis_tready & arp_tx_axis_tvalid)
				next_state <= ARP_DATA_2     ;
			else
				next_state <= ARP_DATA_1     ;
		end
	  ARP_DATA_2 :
		begin
			if (arp_tx_axis_tready & arp_tx_axis_tvalid)
				next_state <= ARP_DATA_3     ;
			else
				next_state <= ARP_DATA_2     ;
		end
	  ARP_DATA_3 :
		begin
			if (arp_tx_axis_tready & arp_tx_axis_tvalid)
				next_state <= ARP_END     ;
			else
				next_state <= ARP_DATA_3     ;
		end
	  ARP_TIMEOUT : 
			next_state <= IDLE ;
	  ARP_END :
            next_state <= IDLE ;
      default          :
        next_state <= IDLE ;
    endcase
  end

/* timeout counter control */	
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      timeout <= 32'd0 ;
    else if (state == ARP_DATA_0)
      timeout <= timeout + 1  ;
    else 
      timeout <= 0 ;
  end
/* arp operation code register */	  
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      op <= 16'd0 ;
    else if (state == ARP_REPLY_WAIT)
      op <= ARP_REPLY_CODE  ;
    else if (state == ARP_REQUEST_WAIT)
      op <= ARP_REQUEST_CODE ;
  end
   
/* arp destination ip address register */	
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      arp_dst_ip_addr  <=  32'd0  ;
    else if (state == ARP_REQUEST_WAIT || state == ARP_REPLY_WAIT)
      arp_dst_ip_addr  <= dst_ip_addr ;
  end
/* arp destination mac address register */	  
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      arp_dst_mac_addr  <=  48'd0  ;
    else if (state == ARP_REQUEST_WAIT || state == ARP_REPLY_WAIT)
      arp_dst_mac_addr  <= dst_mac_addr ;
  end
  
/* always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      arp_dst_ip_addr  <=  32'd0  ;
    else if (state == ARP_REQUEST_WAIT)
      arp_dst_ip_addr  <= dst_ip_addr ;
    else if (state == ARP_REPLY_WAIT)
      arp_dst_ip_addr  <= arp_rcvd_src_ip_addr ;
  end
  
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      arp_dst_mac_addr  <=  48'd0  ;
    else if (state == ARP_REQUEST_WAIT)
      arp_dst_mac_addr  <= dst_mac_addr ;
    else if (state == ARP_REPLY_WAIT)
      arp_dst_mac_addr  <= arp_rcvd_src_mac_addr ;
  end */

/* arp request ack control */	  
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      arp_request_ack  <=  1'b0 ;
    else if (state == ARP_REQUEST_WAIT)
      arp_request_ack  <= 1'b1 ;
    else if (~arp_request_req)
      arp_request_ack  <=  1'b0 ;
  end 
/* arp reply ack control */	 
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      arp_reply_ack  <=  1'b0 ;
    else if (state == ARP_REPLY_WAIT)
      arp_reply_ack  <= 1'b1 ;
    else if (~arp_reply_req)
      arp_reply_ack  <=  1'b0 ;
  end
 /* arp not empty signal, means it can transmit arp data now */	
 always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      arp_not_empty  <=  1'b0 ;
    else if (state == ARP_REPLY_WAIT || state == ARP_REQUEST_WAIT)
      arp_not_empty  <= 1'b1 ;
    else if (state == ARP_DATA_1)
      arp_not_empty  <=  1'b0 ;
  end
 
 
 
always @(*)
   begin
	if (arp_tx_axis_tready)
	begin
      case (state)
         ARP_DATA_0      	: arp_tx_axis_tvalid   <= 1'b1 ;
         ARP_DATA_1			: arp_tx_axis_tvalid   <= 1'b1 ;
         ARP_DATA_2  		: arp_tx_axis_tvalid   <= 1'b1 ;
         ARP_DATA_3      	: arp_tx_axis_tvalid   <= 1'b1 ;
         default   			: arp_tx_axis_tvalid   <= 1'b0 ;
      endcase
	end
	else
		arp_tx_axis_tvalid   <= 1'b0 ;
   end
   
always @(*)
   begin
	if (arp_tx_axis_tready)
		begin
		if (state == ARP_DATA_3)
			arp_tx_axis_tlast   <= 1'b1 ;
		else
			arp_tx_axis_tlast   <= 1'b0 ;
		end
	else
		arp_tx_axis_tlast   <= 1'b0 ;
   end
   
always @(*)
   begin
      case (state)
         ARP_DATA_0      	: arp_tx_axis_tkeep   <= 8'hff ;
         ARP_DATA_1			: arp_tx_axis_tkeep   <= 8'hff ;
         ARP_DATA_2  		: arp_tx_axis_tkeep   <= 8'hff ;
         ARP_DATA_3      	: arp_tx_axis_tkeep   <= 8'h0f ;
         default   			: arp_tx_axis_tkeep   <= 8'h00 ;
      endcase
   end
  // Form arp_tx_axis_tdata here
   // opreg7to0

always @(*)
   begin
      case (state)
         ARP_DATA_0      	: arp_tx_axis_tdata[7:0]    <= hardware_type[15:8];
         ARP_DATA_1			: arp_tx_axis_tdata[7:0]    <= src_mac_addr[47:40];
         ARP_DATA_2  		: arp_tx_axis_tdata[7:0]    <= src_ip_addr[15:8];
         ARP_DATA_3      	: arp_tx_axis_tdata[7:0]    <= arp_dst_ip_addr[31:24];
         default   			: arp_tx_axis_tdata[7:0]    <= 8'h00;
      endcase
   end

   // opreg15to8

always @(*)
   begin
      case (state)
         ARP_DATA_0  		: arp_tx_axis_tdata[15:8]   <= hardware_type[7:0];
         ARP_DATA_1			: arp_tx_axis_tdata[15:8]   <= src_mac_addr[39:32];
         ARP_DATA_2  		: arp_tx_axis_tdata[15:8]   <= src_ip_addr[7:0];
		 ARP_DATA_3			: arp_tx_axis_tdata[15:8]   <= arp_dst_ip_addr[23:16];
         default   			: arp_tx_axis_tdata[15:8]   <= 8'h00;
      endcase
   end

   // opreg23to16

always @(*)
   begin
      case (state)
         ARP_DATA_0  		: arp_tx_axis_tdata[23:16]  <= protocol_type[15:8];
         ARP_DATA_1			: arp_tx_axis_tdata[23:16]  <= src_mac_addr[31:24];
         ARP_DATA_2  		: arp_tx_axis_tdata[23:16]  <= arp_dst_mac_addr[47:40];
		 ARP_DATA_3      	: arp_tx_axis_tdata[23:16]  <= arp_dst_ip_addr[15:8];
         default   			: arp_tx_axis_tdata[23:16]  <= 8'h00;
      endcase
   end

   // opreg31to24

always @(*)
   begin
      case (state)
         ARP_DATA_0  		: arp_tx_axis_tdata[31:24]  <= protocol_type[7:0];
         ARP_DATA_1			: arp_tx_axis_tdata[31:24]  <= src_mac_addr[23:16];
         ARP_DATA_2  		: arp_tx_axis_tdata[31:24]  <= arp_dst_mac_addr[39:32];
		 ARP_DATA_3      	: arp_tx_axis_tdata[31:24]  <= arp_dst_ip_addr[7:0];
         default  			: arp_tx_axis_tdata[31:24]  <= 8'h00;
      endcase
   end

   // opreg39to32

always @(*)
   begin
      case (state)
         ARP_DATA_0  		: arp_tx_axis_tdata[39:32]  <= mac_length;
         ARP_DATA_1			: arp_tx_axis_tdata[39:32]  <= src_mac_addr[15:8];
         ARP_DATA_2  		: arp_tx_axis_tdata[39:32]  <= arp_dst_mac_addr[31:24];
		 ARP_DATA_3      	: arp_tx_axis_tdata[39:32]  <= 8'h00;
         default   			: arp_tx_axis_tdata[39:32]  <= 8'h00;
      endcase
   end

   // opreg47to40

always @(*)
   begin
       case (state)
         ARP_DATA_0  		: arp_tx_axis_tdata[47:40]  <= ip_length;
         ARP_DATA_1			: arp_tx_axis_tdata[47:40]  <= src_mac_addr[7:0];
         ARP_DATA_2  		: arp_tx_axis_tdata[47:40]  <= arp_dst_mac_addr[23:16];
		 ARP_DATA_3      	: arp_tx_axis_tdata[47:40]  <= 8'h00;
         default   			: arp_tx_axis_tdata[47:40]  <= 8'h00;
      endcase
   end

   // opreg55to48

always @(*)
   begin
      case (state)
         ARP_DATA_0  		: arp_tx_axis_tdata[55:48]  <= op[15:8];
         ARP_DATA_1			: arp_tx_axis_tdata[55:48]  <= src_ip_addr[31:24];
         ARP_DATA_2  		: arp_tx_axis_tdata[55:48]  <= arp_dst_mac_addr[15:8];
		 ARP_DATA_3      	: arp_tx_axis_tdata[55:48]  <= 8'h00;
         default   			: arp_tx_axis_tdata[55:48]  <= 8'h00;
      endcase
   end

   // opreg63to56

always @(*)
   begin
      case (state)
         ARP_DATA_0  		: arp_tx_axis_tdata[63:56]  <= op[7:0];
         ARP_DATA_1			: arp_tx_axis_tdata[63:56]  <= src_ip_addr[23:16];
         ARP_DATA_2  		: arp_tx_axis_tdata[63:56]  <= arp_dst_mac_addr[7:0];
		 ARP_DATA_3      	: arp_tx_axis_tdata[63:56]  <= 8'h00;
         default   			: arp_tx_axis_tdata[63:56]  <= 8'h00;
      endcase
   end	
  

  
  
endmodule



// IP Decryptor end

