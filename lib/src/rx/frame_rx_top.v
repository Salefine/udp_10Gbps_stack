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
//   Description:  frame receive top, instantiate rx module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/


module frame_rx_top(
	input                            	     rx_axis_aclk,
	input                            	     rx_axis_areset,
	/* axis	interface from mac  */	
    input  [63:0]       	     			 mac_rx_axis_tdata,
    input  [7:0]     	     				 mac_rx_axis_tkeep,
    input                            	     mac_rx_axis_tvalid,		 
    input                            	     mac_rx_axis_tlast,
    input                           	     mac_rx_axis_tusr,
	/* udp axis	interface to user  */	
	output  [63:0]       	     			 udp_rx_axis_tdata,
    output  [7:0]     	     				 udp_rx_axis_tkeep,
    output                            	     udp_rx_axis_tvalid,		 
    output                            	     udp_rx_axis_tlast,
    output                           	     udp_rx_axis_tusr,
	/* axis	interface to icmp module  */
	output   [63:0]       	     		 	 ip_to_icmp_axis_tdata  ,
	output   [7:0]     	     			 	 ip_to_icmp_axis_tkeep  ,
	output                           	 	 ip_to_icmp_axis_tvalid ,
	output                           	 	 ip_to_icmp_axis_tlast  ,
	output                          	 	 ip_to_icmp_axis_tusr   ,
	
	
	input  [31:0]							 local_ip_addr,		//local ip address defined by user
	input  [47:0]							 local_mac_addr,	//local mac address defined by user
	input  [31:0]							 dst_ip_addr,		//destinations ip address defined by user
	output [47:0]							 dst_mac_addr,		//destinations mac address 
	
	output                 				 	 arp_reply_req,     //arp reply request to arp tx module
	input 	         						 arp_reply_ack,     //arp reply ack from arp tx module 
	input				  					 arp_request_ack,	//arp request ack from arp tx module
	output				  					 arp_request_req,   //arp request to arp tx module 
	
	output									 mac_exist			// mac exist signal
	
	
    );
/* frame rx axis interface */	
wire   [63:0]       	     		 frame_rx_axis_tdata  ;
wire   [7:0]     	     			 frame_rx_axis_tkeep  ;
wire                           	 	 frame_rx_axis_tvalid ;		 
wire                           	 	 frame_rx_axis_tlast  ;
wire                          	 	 frame_rx_axis_tusr   ;
/* axis interface to ip module */
wire   [63:0]       	     		 frame_to_ip_axis_tdata  ;
wire   [7:0]     	     			 frame_to_ip_axis_tkeep  ;
wire                           	 	 frame_to_ip_axis_tvalid ;		 
wire                           	 	 frame_to_ip_axis_tlast  ;
wire                          	 	 frame_to_ip_axis_tusr   ;
/* axis interface to arp module */
wire   [63:0]       	     		 frame_to_arp_axis_tdata  ;
wire   [7:0]     	     			 frame_to_arp_axis_tkeep  ;
wire                           	 	 frame_to_arp_axis_tvalid ;		 
wire                           	 	 frame_to_arp_axis_tlast  ;
wire                          	 	 frame_to_arp_axis_tusr   ;
/* ip axis interface */
wire   [63:0]       	     		 ip_rx_axis_tdata  ;
wire   [7:0]     	     			 ip_rx_axis_tkeep  ;
wire                           	 	 ip_rx_axis_tvalid ;		 
wire                           	 	 ip_rx_axis_tlast  ;
wire                          	 	 ip_rx_axis_tusr   ;

wire   [47:0]						 rcvd_dst_mac_addr    ;
wire   [47:0]						 rcvd_src_mac_addr    ;
wire   [15:0]						 rcvd_type            ;
wire   [47:0]						 frame_mode_dst_mac_addr ;

wire  [7:0]							 ip_type ;				//ip type, icmp or udp
wire  [31:0]						 rcvd_dst_ip_addr ;		
wire  [31:0]						 rcvd_src_ip_addr ;
wire  [31:0]						 ip_mode_dst_ip_addr ;
wire  [31:0]						 ip_mode_src_ip_addr ;

/* axis interface to udp module */
wire   [63:0]       	     		 ip_to_udp_axis_tdata  ;
wire   [7:0]     	     			 ip_to_udp_axis_tkeep  ;
wire                           	 	 ip_to_udp_axis_tvalid ;		 
wire                           	 	 ip_to_udp_axis_tlast  ;
wire                          	 	 ip_to_udp_axis_tusr   ;


wire  [47:0]						 arp_rcvd_src_mac_addr	;
wire  [31:0]						 arp_rcvd_src_ip_addr ;
wire 								 arp_valid ;


/* Instantiate arp cache module */
arp_cache  cache_inst
       (
         .clk                    (rx_axis_aclk  ),
         .rst_n                  (rx_axis_areset),
         .arp_valid              (arp_valid            ),
         .arp_rcvd_src_ip_addr   (arp_rcvd_src_ip_addr ),
         .arp_rcvd_src_mac_addr  (arp_rcvd_src_mac_addr),       
         .dst_ip_addr            (dst_ip_addr          ),
         .dst_mac_addr           (dst_mac_addr         ),
		 .arp_request_ack        (arp_request_ack),
		 .arp_request_req        (arp_request_req),
         .mac_exist              (mac_exist            )
       ) ;


/* Instantiate frame rx  module */	
frame_rx frame_rx_inst
	(	
	 .rx_axis_aclk              (rx_axis_aclk        ),
	 .rx_axis_areset	        (rx_axis_areset	     ),	
     .mac_rx_axis_tdata         (mac_rx_axis_tdata   ),
     .mac_rx_axis_tkeep         (mac_rx_axis_tkeep   ),
     .mac_rx_axis_tvalid        (mac_rx_axis_tvalid  ),		 
     .mac_rx_axis_tlast         (mac_rx_axis_tlast   ),
     .mac_rx_axis_tusr	        (mac_rx_axis_tusr	 ),
	 
	 .frame_rx_axis_tdata       (frame_rx_axis_tdata ),
     .frame_rx_axis_tkeep       (frame_rx_axis_tkeep ),
     .frame_rx_axis_tvalid		(frame_rx_axis_tvalid),   
     .frame_rx_axis_tlast       (frame_rx_axis_tlast ),
     .frame_rx_axis_tusr	    (frame_rx_axis_tusr	 ),
	 .local_mac_addr            (local_mac_addr      ),
	 .rcvd_dst_mac_addr         (rcvd_dst_mac_addr   ),
	 .rcvd_src_mac_addr         (rcvd_src_mac_addr   ),
	 .rcvd_type                 (rcvd_type           )
    );

/* Instantiate frame rx mode module */
frame_rx_mode  frame_rx_mode_inst
	(
		.rx_axis_aclk               (rx_axis_aclk        ),
		.rx_axis_areset		        (rx_axis_areset		 ),
		.frame_rx_axis_tdata        (frame_rx_axis_tdata ),
        .frame_rx_axis_tkeep        (frame_rx_axis_tkeep ),
        .frame_rx_axis_tvalid	    (frame_rx_axis_tvalid),	 
        .frame_rx_axis_tlast        (frame_rx_axis_tlast ),
        .frame_rx_axis_tusr		    (frame_rx_axis_tusr	),
		.rcvd_dst_mac_addr          (rcvd_dst_mac_addr   ),
		.rcvd_src_mac_addr          (rcvd_src_mac_addr   ),
		.rcvd_type		            (rcvd_type		     ),
		.ip_rx_axis_tdata           (frame_to_ip_axis_tdata    ),
        .ip_rx_axis_tkeep           (frame_to_ip_axis_tkeep    ),
        .ip_rx_axis_tvalid		    (frame_to_ip_axis_tvalid	), 
        .ip_rx_axis_tlast           (frame_to_ip_axis_tlast    ),
        .ip_rx_axis_tusr		    (frame_to_ip_axis_tusr	),
		.arp_rx_axis_tdata          (frame_to_arp_axis_tdata   ),
        .arp_rx_axis_tkeep          (frame_to_arp_axis_tkeep   ),
        .arp_rx_axis_tvalid		    (frame_to_arp_axis_tvalid	), 
        .arp_rx_axis_tlast          (frame_to_arp_axis_tlast   ),
        .arp_rx_axis_tusr		    (frame_to_arp_axis_tusr	),
		.frame_mode_dst_mac_addr    (frame_mode_dst_mac_addr        ),
		.frame_mode_src_mac_addr    (        )
    );
/* Instantiate arp rx module */
arp_rx arp_rx_inst
	(
		.rx_axis_aclk           	(rx_axis_aclk        ),
		.rx_axis_areset         	(rx_axis_areset      ),
		.frame_rx_axis_tdata    	(frame_to_arp_axis_tdata ),
        .frame_rx_axis_tkeep    	(frame_to_arp_axis_tkeep ),
        .frame_rx_axis_tvalid		(frame_to_arp_axis_tvalid),	 
        .frame_rx_axis_tlast    	(frame_to_arp_axis_tlast ),
        .frame_rx_axis_tusr	    	(frame_to_arp_axis_tusr	 ),
		.local_mac_addr         	(local_mac_addr      ),
		.local_ip_addr          	(local_ip_addr       ),
		.arp_reply_req          	(arp_reply_req       ), 	
		.arp_reply_ack          	(arp_reply_ack       ), 	
		.arp_valid              	(arp_valid           ),
		.arp_rcvd_src_ip_addr		(arp_rcvd_src_ip_addr ),
		.arp_rcvd_src_mac_addr      (arp_rcvd_src_mac_addr),
		.dst_ip_addr				(dst_ip_addr		 )
    );
/* Instantiate ip rx module */	
ip_rx ip_rx_inst
	(
		.rx_axis_aclk                 (rx_axis_aclk        ),
		.rx_axis_areset               (rx_axis_areset      ),
		.frame_rx_axis_tdata          (frame_to_ip_axis_tdata ),
        .frame_rx_axis_tkeep          (frame_to_ip_axis_tkeep ),
        .frame_rx_axis_tvalid		  (frame_to_ip_axis_tvalid),
        .frame_rx_axis_tlast          (frame_to_ip_axis_tlast ),
        .frame_rx_axis_tusr		      (frame_to_ip_axis_tusr	),
		.ip_rx_axis_tdata             (ip_rx_axis_tdata    ),
        .ip_rx_axis_tkeep             (ip_rx_axis_tkeep    ),
        .ip_rx_axis_tvalid		      (ip_rx_axis_tvalid	),
        .ip_rx_axis_tlast             (ip_rx_axis_tlast    ),
        .ip_rx_axis_tusr		      (ip_rx_axis_tusr	),
		.local_ip_addr                (local_ip_addr       ),
		.local_mac_addr				  (local_mac_addr	),
		.rcvd_dst_mac_addr			  (frame_mode_dst_mac_addr		),
		.ip_type					  (ip_type		),
		.rcvd_dst_ip_addr			  (rcvd_dst_ip_addr ),
		.rcvd_src_ip_addr			  (rcvd_src_ip_addr )
    );
/* Instantiate ip rx mode module */	
ip_rx_mode ip_rx_mode_inst
	(
	.rx_axis_aclk                     (rx_axis_aclk       ),
	.rx_axis_areset		              (rx_axis_areset		),
	.ip_rx_axis_tdata                 (ip_rx_axis_tdata   ),
    .ip_rx_axis_tkeep                 (ip_rx_axis_tkeep   ),
    .ip_rx_axis_tvalid		          (ip_rx_axis_tvalid	),
    .ip_rx_axis_tlast                 (ip_rx_axis_tlast   ),
    .ip_rx_axis_tusr		          (ip_rx_axis_tusr	),
	.rcvd_dst_ip_addr                 (rcvd_dst_ip_addr   ),
	.rcvd_src_ip_addr			      (rcvd_src_ip_addr ),
	.rcvd_type		                  (ip_type		    ),
	.udp_rx_axis_tdata                (ip_to_udp_axis_tdata  ),
    .udp_rx_axis_tkeep                (ip_to_udp_axis_tkeep  ),
    .udp_rx_axis_tvalid		          (ip_to_udp_axis_tvalid	),
    .udp_rx_axis_tlast                (ip_to_udp_axis_tlast  ),
    .udp_rx_axis_tusr		          (ip_to_udp_axis_tusr	),
	.icmp_rx_axis_tdata               (ip_to_icmp_axis_tdata ),
    .icmp_rx_axis_tkeep               (ip_to_icmp_axis_tkeep ),
    .icmp_rx_axis_tvalid		      (ip_to_icmp_axis_tvalid),
    .icmp_rx_axis_tlast               (ip_to_icmp_axis_tlast ),
    .icmp_rx_axis_tusr		          (ip_to_icmp_axis_tusr	),
	.ip_mode_dst_ip_addr              (ip_mode_dst_ip_addr        ),
	.ip_mode_src_ip_addr              (ip_mode_src_ip_addr        )
    );

/* Instantiate udp rx module */
udp_rx udp_rx_inst
	(
		.rx_axis_aclk            (rx_axis_aclk       ),
		.rx_axis_areset          (rx_axis_areset     ),
		.ip_rx_axis_tdata        (ip_to_udp_axis_tdata   ),
        .ip_rx_axis_tkeep        (ip_to_udp_axis_tkeep   ),
        .ip_rx_axis_tvalid		 (ip_to_udp_axis_tvalid	),
        .ip_rx_axis_tlast        (ip_to_udp_axis_tlast   ),
        .ip_rx_axis_tusr		 (ip_to_udp_axis_tusr	),
		.udp_rx_axis_tdata       (udp_rx_axis_tdata  ),
        .udp_rx_axis_tkeep       (udp_rx_axis_tkeep  ),
        .udp_rx_axis_tvalid		 (udp_rx_axis_tvalid	),
        .udp_rx_axis_tlast       (udp_rx_axis_tlast  ),
        .udp_rx_axis_tusr        (udp_rx_axis_tusr   ),
		.rcvd_dst_ip_addr        (ip_mode_dst_ip_addr      ),
		.rcvd_src_ip_addr	     (ip_mode_src_ip_addr )
    );

	
endmodule



// IP Decryptor end

