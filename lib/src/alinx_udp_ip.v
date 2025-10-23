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
//   Description:  udp ip top module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/


module alinx_udp_ip
#(
	parameter ALINX_CODE = 1
)
(
	
	input  [31:0]							 local_ip_addr,		//local ip address
	input  [47:0]							 local_mac_addr,    //local mac address
	input  [31:0]							 dst_ip_addr,       //destination ip address
	input  [15:0]               			 udp_src_port,      //udp source port
    input  [15:0]               			 udp_dst_port,	    //udp destination port
	
	output									 udp_active,		//udp is in active state, user can send data now
	//rx interface
	input                            	     rx_axis_aclk,
	input                            	     rx_axis_areset,
    input  [63:0]       	     			 mac_rx_axis_tdata,
    input  [7:0]     	     				 mac_rx_axis_tkeep,
    input                            	     mac_rx_axis_tvalid,		 
    input                            	     mac_rx_axis_tlast,
    input                           	     mac_rx_axis_tusr,	
	output  [63:0]       	     			 udp_rx_axis_tdata,
    output  [7:0]     	     				 udp_rx_axis_tkeep,
    output                            	     udp_rx_axis_tvalid,		 
    output                            	     udp_rx_axis_tlast,
    output                           	     udp_rx_axis_tusr,
	//tx interface
	input                            		 tx_axis_aclk,
    input                            		 tx_axis_areset,	
	input  [63:0]       			 		 udp_tx_axis_tdata,
    input  [7:0]     				 		 udp_tx_axis_tkeep,
    input                            		 udp_tx_axis_tvalid,		 
    input                            		 udp_tx_axis_tlast,
    output                           		 udp_tx_axis_tready,		 
	output   [63:0]    						 mac_tx_axis_tdata,
	output   [7:0]     						 mac_tx_axis_tkeep,
	output             						 mac_tx_axis_tvalid,	
	output             						 mac_tx_axis_tlast,
    input                					 mac_tx_axis_tready
	
	
    );


wire							mac_exist ;				//mac exist in arp cache

wire              				arp_request_req;        //arp request
wire            				arp_request_ack;        //arp request ack
wire              				arp_reply_req;          //arp reply request from arp rx module
wire           					arp_reply_ack;          //arp reply ack to arp rx module 	

wire  [47:0]					dst_mac_addr ;			//destination mac address, located in arp cache

wire  [31:0]        			arp_rcvd_src_ip_addr;	//arp received source ip address
wire  [47:0]        			arp_rcvd_src_mac_addr; 	//arp received source mac address
/* ip to icmp axis interface */
wire [63:0]       	     		ip_to_icmp_axis_tdata  ;
wire [7:0]     	     			ip_to_icmp_axis_tkeep  ;
wire                         	ip_to_icmp_axis_tvalid ;
wire                         	ip_to_icmp_axis_tlast  ;
wire 							ip_to_icmp_axis_tusr   ;

wire							icmp_not_empty ;		//icmp is ready to send data
/* icmp axis interface */
wire [63:0]       	   	    	icmp_tx_axis_tdata  ;
wire [7:0]     	     	    	icmp_tx_axis_tkeep  ;
wire                         	icmp_tx_axis_tvalid ;
wire                         	icmp_tx_axis_tlast  ;
wire                         	icmp_tx_axis_tready ;

assign udp_active = mac_exist ;		//udp active is equals to mac exist

generate 
if (ALINX_CODE == 6997)
begin
	/* Instantiate rx module */	
	frame_rx_top frame_rx_top_inst
		(
		.rx_axis_aclk              		(rx_axis_aclk       ),
		.rx_axis_areset	           		(rx_axis_areset	    ),
		.mac_rx_axis_tdata         		(mac_rx_axis_tdata  ),
		.mac_rx_axis_tkeep         		(mac_rx_axis_tkeep  ),
		.mac_rx_axis_tvalid		   		(mac_rx_axis_tvalid	),  
		.mac_rx_axis_tlast         		(mac_rx_axis_tlast  ),
		.mac_rx_axis_tusr	       		(mac_rx_axis_tusr	),
		.udp_rx_axis_tdata         		(udp_rx_axis_tdata  ),
		.udp_rx_axis_tkeep         		(udp_rx_axis_tkeep  ),
		.udp_rx_axis_tvalid		   		(udp_rx_axis_tvalid	),  
		.udp_rx_axis_tlast         		(udp_rx_axis_tlast  ),
		.udp_rx_axis_tusr	       		(udp_rx_axis_tusr	),
		.ip_to_icmp_axis_tdata     		(ip_to_icmp_axis_tdata ),
		.ip_to_icmp_axis_tkeep     		(ip_to_icmp_axis_tkeep ),
		.ip_to_icmp_axis_tvalid    		(ip_to_icmp_axis_tvalid),
		.ip_to_icmp_axis_tlast     		(ip_to_icmp_axis_tlast ),
		.ip_to_icmp_axis_tusr      		(ip_to_icmp_axis_tusr  ),	
		.local_ip_addr             		(local_ip_addr      ),
		.local_mac_addr            		(local_mac_addr     ),
		.dst_ip_addr	           		(dst_ip_addr	   		 ),
		.dst_mac_addr	           		(dst_mac_addr	    ),
		.arp_reply_req             		(arp_reply_req      ), 	
		.arp_reply_ack             		(arp_reply_ack      ), 
		.arp_request_ack        		(arp_request_ack	),
		.arp_request_req        		(arp_request_req	),	
		.mac_exist                 		(mac_exist          )
		
		
		);	
		
	/* Instantiate tx module */		
	frame_tx_top frame_tx_top_inst
		(
			.src_mac_addr              (local_mac_addr         ),
			.dst_mac_addr              (dst_mac_addr         ),
			.src_ip_addr               (local_ip_addr          ),
			.dst_ip_addr               (dst_ip_addr          ),                            
			.udp_src_port              (udp_src_port         ),
			.udp_dst_port		       (udp_dst_port		  ),
			.mac_exist		           (mac_exist		      ),
			.arp_request_req           (arp_request_req      ),
			.arp_request_ack           (arp_request_ack      ),
			.arp_reply_req             (arp_reply_req        ),
			.arp_reply_ack             (arp_reply_ack        ),
			.tx_axis_aclk              (tx_axis_aclk         ),
			.tx_axis_areset  		   (tx_axis_areset  		),
			.icmp_not_empty			   (icmp_not_empty  ),
			.icmp_tx_axis_tdata        (icmp_tx_axis_tdata ),
			.icmp_tx_axis_tkeep        (icmp_tx_axis_tkeep ),
			.icmp_tx_axis_tvalid	   (icmp_tx_axis_tvalid), 	 
			.icmp_tx_axis_tlast        (icmp_tx_axis_tlast ),
			.icmp_tx_axis_tready       (icmp_tx_axis_tready  ),		
			.udp_tx_axis_tdata         (udp_tx_axis_tdata    ),
			.udp_tx_axis_tkeep         (udp_tx_axis_tkeep    ),
			.udp_tx_axis_tvalid		   (udp_tx_axis_tvalid		),
			.udp_tx_axis_tlast         (udp_tx_axis_tlast    ),
			.udp_tx_axis_tready		   (udp_tx_axis_tready		),
			.mac_tx_axis_tdata         (mac_tx_axis_tdata    ),
			.mac_tx_axis_tkeep         (mac_tx_axis_tkeep    ),
			.mac_tx_axis_tvalid	       (mac_tx_axis_tvalid	  ),
			.mac_tx_axis_tlast         (mac_tx_axis_tlast    ),
			.mac_tx_axis_tready        (mac_tx_axis_tready   )
	
		);	
		
	/* Instantiate icmp reply module */	
	icmp_reply icmp_reply_inst
		(
			.rx_axis_aclk           	(rx_axis_aclk       ),
			.rx_axis_areset         	(rx_axis_areset     ),
			.ip_rx_axis_tdata       	(ip_to_icmp_axis_tdata ),
			.ip_rx_axis_tkeep       	(ip_to_icmp_axis_tkeep ),
			.ip_rx_axis_tvalid			(ip_to_icmp_axis_tvalid),  
			.ip_rx_axis_tlast       	(ip_to_icmp_axis_tlast ),
			.ip_rx_axis_tusr			(ip_to_icmp_axis_tusr  ), 
			.icmp_tx_axis_tdata     	(icmp_tx_axis_tdata ),
			.icmp_tx_axis_tkeep     	(icmp_tx_axis_tkeep ),
			.icmp_tx_axis_tvalid		(icmp_tx_axis_tvalid), 	 
			.icmp_tx_axis_tlast     	(icmp_tx_axis_tlast ),
			.icmp_tx_axis_tready    	(icmp_tx_axis_tready  ),
			.icmp_not_empty				(icmp_not_empty )
			
			
	
		);	
	end
endgenerate
	
	
endmodule



// IP Decryptor end

