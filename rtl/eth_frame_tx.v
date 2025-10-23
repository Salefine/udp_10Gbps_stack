/****************************************************************************
 * @file    eth_frame_tx.v
 * @brief  
 * @author  weslie (zzhi4832@gmail.com)
 * @version 1.0
 * @date    2025-01-22
 * 
 * @par :
 * ___________________________________________________________________________
 * |    Date       |  Version    |       Author     |       Description      |
 * |---------------|-------------|------------------|------------------------|
 * |               |   v1.0      |    weslie        |                        |
 * |---------------|-------------|------------------|------------------------|
 * 
 * @copyright Copyright (c) 2025 welie
 * ***************************************************************************/

`timescale 1ns/1ps

module eth_frame_tx(
    input [47:0]						src_mac_addr,			//source mac address, defined by user
	input [47:0]						dst_mac_addr,           //destination mac address
	input  [31:0]               		src_ip_addr,            //source ip address, defined by user
    input  [31:0]               		dst_ip_addr,            //destination ip address, defined by user                               
    input  [15:0]               		udp_src_port,           //udp source port, defined by user
    input  [15:0]               		udp_dst_port,           //udp destination port, defined by user

    input                               mac_exist,

	input                				arp_request_req,        //arp request
	output             					arp_request_ack,        //arp request ack
	input                				arp_reply_req,          //arp reply request from arp rx module
	output            					arp_reply_ack,          //arp reply ack to arp rx module     

	input                            	tx_axis_aclk,
    input                            	tx_axis_aresetn, 
	/* icmp tx axis interface */	
	input								icmp_not_empty,			//icmp is ready to send data
	input  [63:0]       			 	icmp_tx_axis_tdata,
    input  [7:0]     				 	icmp_tx_axis_tkeep,
    input                            	icmp_tx_axis_tvalid,		 
    input                            	icmp_tx_axis_tlast,
    output                           	icmp_tx_axis_tready,   
	/* udp tx axis interface */	
    input  [63:0]       			 	udp_tx_axis_tdata,
    input  [7:0]     				 	udp_tx_axis_tkeep,
    input                            	udp_tx_axis_tvalid,		 
    input                            	udp_tx_axis_tlast,
    output                           	udp_tx_axis_tready,
	/* mac tx axis interface */	
	output   [63:0]    					mac_tx_axis_tdata,
	output   [7:0]     					mac_tx_axis_tkeep,
	output             					mac_tx_axis_tvalid,	
	output             					mac_tx_axis_tlast,
    input                				mac_tx_axis_tready    
);

wire [63:0]     udp2ip_tx_axis_tdata    ;
wire [7:0]      udp2ip_tx_axis_tkeep    ;
wire            udp2ip_tx_axis_tvalid   ;
wire            udp2ip_tx_axis_tlast    ;
wire            udp_not_empty           ;
wire            udp2ip_tx_axis_tready   ;

wire [63:0]     ip_tx_axis_tdata     ;
wire [7:0]      ip_tx_axis_tkeep     ;
wire            ip_tx_axis_tvalid    ;
wire            ip_tx_axis_tlast     ;
wire            ip_tx_axis_tready    ;
wire [7:0]      ip_send_type         ;
wire            recv_ip_end          ;

wire [63:0]     arp_tx_axis_tdata   ;
wire [7:0]      arp_tx_axis_tkeep   ;
wire            arp_tx_axis_tvalid  ;
wire            arp_tx_axis_tlast   ;
wire            arp_not_empty       ;

wire [63:0]     frame2mac_tx_axis_tdata     ;
wire [7:0]      frame2mac_tx_axis_tkeep     ;
wire            frame2mac_tx_axis_tvalid    ;
wire            frame2mac_tx_axis_tlast     ;
wire            frame2mac_tx_axis_tready    ;
wire            ip_not_empty                ;

wire [63:0]     frame_tx_axis_tdata     ;
wire [7:0]      frame_tx_axis_tkeep     ;
wire            frame_tx_axis_tvalid    ;
wire            frame_tx_axis_tlast     ;
wire            arp_tx_axis_tready      ;
wire [15:0]     protocol_type           ;
wire            rcv_stream_end          ;

us_udp_tx_v1 tx_udp(
    .src_ip_addr        	(src_ip_addr         ),
    .dst_ip_addr        	(dst_ip_addr         ),
    .udp_src_port       	(udp_src_port        ),
    .udp_dst_port       	(udp_dst_port        ),
    .tx_axis_aclk       	(tx_axis_aclk        ),
    .tx_axis_aresetn    	(tx_axis_aresetn     ),
    .udp_tx_axis_tdata  	(udp_tx_axis_tdata   ),
    .udp_tx_axis_tkeep  	(udp_tx_axis_tkeep   ),
    .udp_tx_axis_tvalid 	(udp_tx_axis_tvalid  ),
    .udp_tx_axis_tlast  	(udp_tx_axis_tlast   ),
    .udp_tx_axis_tready 	(udp_tx_axis_tready  ),
    .ip_tx_axis_tdata   	(udp2ip_tx_axis_tdata    ),
    .ip_tx_axis_tkeep   	(udp2ip_tx_axis_tkeep    ),
    .ip_tx_axis_tvalid  	(udp2ip_tx_axis_tvalid   ),
    .ip_tx_axis_tlast   	(udp2ip_tx_axis_tlast    ),
    .ip_tx_axis_tready  	(udp2ip_tx_axis_tready   ),
    .mac_exist          	(mac_exist           ),
    .udp_not_empty      	(udp_not_empty       )
);


// output declaration of module us_ip_tx_mode


us_ip_tx_mode tx_ip_mode(
    .tx_axis_aclk        	(tx_axis_aclk         ),
    .tx_axis_aresetn     	(tx_axis_aresetn      ),

    .ip_tx_axis_tdata    	(ip_tx_axis_tdata     ),
    .ip_tx_axis_tkeep    	(ip_tx_axis_tkeep     ),
    .ip_tx_axis_tvalid   	(ip_tx_axis_tvalid    ),
    .ip_tx_axis_tlast    	(ip_tx_axis_tlast     ),
    .ip_tx_axis_tready   	(ip_tx_axis_tready    ),

    .udp_tx_axis_tdata   	(udp2ip_tx_axis_tdata ),
    .udp_tx_axis_tkeep   	(udp2ip_tx_axis_tkeep ),
    .udp_tx_axis_tvalid  	(udp2ip_tx_axis_tvalid),
    .udp_tx_axis_tlast   	(udp2ip_tx_axis_tlast ),
    .udp_tx_axis_tready  	(udp2ip_tx_axis_tready),

    .icmp_tx_axis_tdata  	(icmp_tx_axis_tdata   ),
    .icmp_tx_axis_tkeep  	(icmp_tx_axis_tkeep   ),
    .icmp_tx_axis_tvalid 	(icmp_tx_axis_tvalid  ),
    .icmp_tx_axis_tlast  	(icmp_tx_axis_tlast   ),
    .icmp_tx_axis_tready 	(icmp_tx_axis_tready  ),

    .udp_not_empty       	(udp_not_empty        ),
    .icmp_not_empty      	(icmp_not_empty       ),
    .ip_send_type        	(ip_send_type         ),
    .recv_ip_end           	(recv_ip_end          )
);

// output declaration of module us_ip_tx


us_ip_tx tx_ip(
    .ip_send_type         	(ip_send_type          ),
    .src_ip_addr          	(src_ip_addr           ),
    .dst_ip_addr          	(dst_ip_addr           ),
    .tx_axis_aclk         	(tx_axis_aclk          ),
    .tx_axis_aresetn      	(tx_axis_aresetn       ),
    .ip_tx_axis_tdata     	(ip_tx_axis_tdata      ),
    .ip_tx_axis_tkeep     	(ip_tx_axis_tkeep      ),
    .ip_tx_axis_tvalid    	(ip_tx_axis_tvalid     ),
    .ip_tx_axis_tlast     	(ip_tx_axis_tlast      ),
    .ip_tx_axis_tready    	(ip_tx_axis_tready     ),
    .frame_tx_axis_tdata  	(frame2mac_tx_axis_tdata   ),
    .frame_tx_axis_tkeep  	(frame2mac_tx_axis_tkeep   ),
    .frame_tx_axis_tvalid 	(frame2mac_tx_axis_tvalid  ),
    .frame_tx_axis_tlast  	(frame2mac_tx_axis_tlast   ),
    .frame_tx_axis_tready 	(frame2mac_tx_axis_tready  ),
    .ip_not_empty         	(ip_not_empty          ),
    .recv_ip_end         	(recv_ip_end       )
);


// output declaration of module us_arp_tx



us_arp_tx tx_arp(
    .tx_axis_aclk       	(tx_axis_aclk        ),
    .tx_axis_aresetn    	(tx_axis_aresetn     ),
    .arp_tx_axis_tdata  	(arp_tx_axis_tdata   ),
    .arp_tx_axis_tkeep  	(arp_tx_axis_tkeep   ),
    .arp_tx_axis_tvalid 	(arp_tx_axis_tvalid  ),
    .arp_tx_axis_tlast  	(arp_tx_axis_tlast   ),
    .arp_tx_axis_tready 	(arp_tx_axis_tready  ),
    .dst_mac_addr       	(dst_mac_addr        ),
    .src_mac_addr       	(src_mac_addr        ),
    .dst_ip_addr        	(dst_ip_addr         ),
    .src_ip_addr        	(src_ip_addr         ),
    .arp_not_empty          (arp_not_empty       ),
    .arp_reply_ack      	(arp_reply_ack       ),
    .arp_reply_req      	(arp_reply_req       ),
    .arp_request_ack    	(arp_request_ack     ),
    .arp_request_req    	(arp_request_req     )
);


// output declaration of module us_mac_frame_mode


mac_tx_mode tx_mac_mode(
    .tx_axis_aclk         	(tx_axis_aclk          ),
    .tx_axis_areset       	(tx_axis_aresetn       ),
    .frame_tx_axis_tdata  	(frame_tx_axis_tdata   ),
    .frame_tx_axis_tkeep  	(frame_tx_axis_tkeep   ),
    .frame_tx_axis_tvalid 	(frame_tx_axis_tvalid  ),
    .frame_tx_axis_tlast  	(frame_tx_axis_tlast   ),
    .frame_tx_axis_tready 	(frame_tx_axis_tready  ),
    .ip_tx_axis_tdata     	(frame2mac_tx_axis_tdata      ),
    .ip_tx_axis_tkeep     	(frame2mac_tx_axis_tkeep      ),
    .ip_tx_axis_tvalid    	(frame2mac_tx_axis_tvalid     ),
    .ip_tx_axis_tlast     	(frame2mac_tx_axis_tlast      ),
    .ip_tx_axis_tready    	(frame2mac_tx_axis_tready     ),
    .arp_tx_axis_tdata    	(arp_tx_axis_tdata     ),
    .arp_tx_axis_tkeep    	(arp_tx_axis_tkeep     ),
    .arp_tx_axis_tvalid   	(arp_tx_axis_tvalid    ),
    .arp_tx_axis_tlast    	(arp_tx_axis_tlast     ),
    .arp_tx_axis_tready   	(arp_tx_axis_tready    ),
    .ip_not_empty         	(ip_not_empty          ),
    .arp_not_empty        	(arp_not_empty         ),
    .rcv_stream_end       	(rcv_stream_end        ),
    .protocol_type        	(protocol_type         )
);

// output declaration of module us_mac_frame_tx


us_mac_tx tx_mac(
    .src_mac_addr         	(src_mac_addr          ),
    .dst_mac_addr         	(dst_mac_addr          ),
    .eth_type             	(protocol_type              ),
    .recv_axis_end        	(rcv_stream_end         ),
    .tx_axis_aclk         	(tx_axis_aclk          ),
    .tx_axis_aresetn      	(tx_axis_aresetn       ),
    .frame_tx_axis_tdata  	(frame_tx_axis_tdata   ),
    .frame_tx_axis_tkeep  	(frame_tx_axis_tkeep   ),
    .frame_tx_axis_tvalid 	(frame_tx_axis_tvalid  ),
    .frame_tx_axis_tlast  	(frame_tx_axis_tlast   ),
    .frame_tx_axis_tready 	(frame_tx_axis_tready  ),
    .mac_tx_axis_tdata    	(mac_tx_axis_tdata     ),
    .mac_tx_axis_tkeep    	(mac_tx_axis_tkeep     ),
    .mac_tx_axis_tvalid   	(mac_tx_axis_tvalid    ),
    .mac_tx_axis_tlast    	(mac_tx_axis_tlast     ),
    .mac_tx_axis_tready   	(mac_tx_axis_tready    )
);


endmodule


