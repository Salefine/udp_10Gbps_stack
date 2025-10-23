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
//   Description:  frame tx top module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/


module frame_tx_top(
		input [47:0]						src_mac_addr,			//source mac address, defined by user
		input [47:0]						dst_mac_addr,           //destination mac address
		input  [31:0]               		src_ip_addr,            //source ip address, defined by user
        input  [31:0]               		dst_ip_addr,            //destination ip address, defined by user                               
        input  [15:0]               		udp_src_port,           //udp source port, defined by user
        input  [15:0]               		udp_dst_port,           //udp destination port, defined by user
		
		input								mac_exist,				//mac exist in arp cache
		
		input                				arp_request_req,        //arp request
		output             					arp_request_ack,        //arp request ack
		input                				arp_reply_req,          //arp reply request from arp rx module
		output            					arp_reply_ack,          //arp reply ack to arp rx module     
		
        
		input                            	tx_axis_aclk,
        input                            	tx_axis_areset,  
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

wire 							ip_rcv_stream_end ;			//ip receive stream end from udp or icmp
wire							frame_rcv_stream_end ;		//frame receive stream end from ip or arp

wire [7:0]						ip_send_type ;		//ip send type, udp or icmp

wire							udp_not_empty;		//udp is ready to send data
wire							ip_not_empty;       //ip is ready to send data
wire							arp_not_empty;      //arp is ready to send data

wire [15:0]						protocol_type ;		//frame type, ip or arp

/* udp to ip axis interface */	
wire [63:0]       			 	udp_to_ip_axis_tdata;
wire [7:0]     				 	udp_to_ip_axis_tkeep;
wire                           	udp_to_ip_axis_tvalid;		 
wire                           	udp_to_ip_axis_tlast;
wire                           	udp_to_ip_axis_tready;
/* ip axis interface */	
wire [63:0]       			 	ip_tx_axis_tdata;
wire [7:0]     				 	ip_tx_axis_tkeep;
wire                           	ip_tx_axis_tvalid;		 
wire                           	ip_tx_axis_tlast;
wire                           	ip_tx_axis_tready;
/* ip to frame axis interface */	
wire [63:0]       			 	ip_to_frame_axis_tdata;
wire [7:0]     				 	ip_to_frame_axis_tkeep;
wire                           	ip_to_frame_axis_tvalid;		 
wire                           	ip_to_frame_axis_tlast;
wire                           	ip_to_frame_axis_tready;
/* arp to frame axis interface */	
wire [63:0]       			 	arp_to_frame_axis_tdata;
wire [7:0]     				 	arp_to_frame_axis_tkeep;
wire                           	arp_to_frame_axis_tvalid;		 
wire                           	arp_to_frame_axis_tlast;
wire                           	arp_to_frame_axis_tready;
/* frame axis interface */	
wire [63:0]       			 	frame_tx_axis_tdata;
wire [7:0]     				 	frame_tx_axis_tkeep;
wire                           	frame_tx_axis_tvalid;		 
wire                           	frame_tx_axis_tlast;
wire                           	frame_tx_axis_tready;
/* Instantiate udp tx module */	
udp_tx  udp_inst
       (                                         
          .src_ip_addr             	  (src_ip_addr           ),
          .dst_ip_addr        		  (dst_ip_addr      ),        
          .udp_src_port      		  (udp_src_port     ),
          .udp_dst_port 			  (udp_dst_port),    
		  .tx_axis_aclk               (tx_axis_aclk      ),
          .tx_axis_areset             (tx_axis_areset    ),                           
          .udp_tx_axis_tdata          (udp_tx_axis_tdata ),
          .udp_tx_axis_tkeep          (udp_tx_axis_tkeep ),
          .udp_tx_axis_tvalid 		  (udp_tx_axis_tvalid),
          .udp_tx_axis_tlast          (udp_tx_axis_tlast ),
          .udp_tx_axis_tready         (udp_tx_axis_tready),
		  .ip_tx_axis_tdata           (udp_to_ip_axis_tdata  ),
          .ip_tx_axis_tkeep           (udp_to_ip_axis_tkeep  ),
          .ip_tx_axis_tvalid 		  (udp_to_ip_axis_tvalid ),
          .ip_tx_axis_tlast           (udp_to_ip_axis_tlast  ),
          .ip_tx_axis_tready          (udp_to_ip_axis_tready ),
		  .mac_exist				  (mac_exist		),
		  .udp_not_empty			  (udp_not_empty )
         
       ) ;

/* Instantiate ip tx module */	
ip_tx ip_inst
       (        
         .ip_send_type 			   (ip_send_type 		), 
         .src_ip_addr              (src_ip_addr         ),
         .dst_ip_addr 			   (dst_ip_addr 		), 
		 .ip_not_empty			   (ip_not_empty		),
		 .tx_axis_aclk             (tx_axis_aclk        ),
         .tx_axis_areset   		   (tx_axis_areset   	), 			
		 .ip_tx_axis_tdata         (ip_tx_axis_tdata    ),
         .ip_tx_axis_tkeep         (ip_tx_axis_tkeep    ),
         .ip_tx_axis_tvalid 	   (ip_tx_axis_tvalid 	), 	 
         .ip_tx_axis_tlast         (ip_tx_axis_tlast    ),
         .ip_tx_axis_tready 	   (ip_tx_axis_tready 	), 				
		 .frame_tx_axis_tdata      (ip_to_frame_axis_tdata ),
		 .frame_tx_axis_tkeep      (ip_to_frame_axis_tkeep ),
		 .frame_tx_axis_tvalid     (ip_to_frame_axis_tvalid),	
		 .frame_tx_axis_tlast      (ip_to_frame_axis_tlast ),
         .frame_tx_axis_tready     (ip_to_frame_axis_tready),
		 .rcv_stream_end		   (ip_rcv_stream_end		)
       ) ;	

/* Instantiate ip tx mode switch module */	
ip_tx_mode ip_tx_mode_inst
       (
		 .tx_axis_aclk            (tx_axis_aclk       ),
         .tx_axis_areset          (tx_axis_areset     ),
		 
		 .ip_tx_axis_tdata        (ip_tx_axis_tdata   ),
         .ip_tx_axis_tkeep        (ip_tx_axis_tkeep   ),
         .ip_tx_axis_tvalid 	  (ip_tx_axis_tvalid  ), 	 
         .ip_tx_axis_tlast        (ip_tx_axis_tlast   ),
         .ip_tx_axis_tready       (ip_tx_axis_tready  ),      

		 .udp_tx_axis_tdata       (udp_to_ip_axis_tdata  ),
         .udp_tx_axis_tkeep       (udp_to_ip_axis_tkeep  ),
         .udp_tx_axis_tvalid      (udp_to_ip_axis_tvalid ),
         .udp_tx_axis_tlast       (udp_to_ip_axis_tlast  ),
         .udp_tx_axis_tready 	  (udp_to_ip_axis_tready ), 	 

		 .icmp_tx_axis_tdata      (icmp_tx_axis_tdata ),
         .icmp_tx_axis_tkeep      (icmp_tx_axis_tkeep ),
         .icmp_tx_axis_tvalid     (icmp_tx_axis_tvalid),
         .icmp_tx_axis_tlast      (icmp_tx_axis_tlast ),
         .icmp_tx_axis_tready 	  (icmp_tx_axis_tready), 
		 .udp_not_empty			  (udp_not_empty		),
		 .icmp_not_empty		  (icmp_not_empty		),
         .ip_send_type            (ip_send_type       ),		 
		 .rcv_stream_end          (ip_rcv_stream_end     )
       );	   
/* Instantiate arp tx module */	
arp_tx arp_inst
    (                    		     
     .dst_mac_addr    			  	 (dst_mac_addr    			),  	
     .src_mac_addr    			  	 (src_mac_addr    			),   	
     .src_ip_addr     			  	 (src_ip_addr     			),   	
     .dst_ip_addr     			  	 (dst_ip_addr     			),   	
     .arp_request_req       	  	 (arp_request_req       	),     	
	 .arp_request_ack       	  	 (arp_request_ack       	),     	
	 .arp_reply_req         	  	 (arp_reply_req         	),     	
     .arp_reply_ack         	  	 (arp_reply_ack         	),   		 
	 .arp_not_empty				  	 (arp_not_empty				),   		 
	 .tx_axis_aclk		             (tx_axis_aclk		    	), 
     .tx_axis_areset			  	 (tx_axis_areset			),   
     .arp_tx_axis_tdata		         (arp_to_frame_axis_tdata	), 
     .arp_tx_axis_tkeep		         (arp_to_frame_axis_tkeep	),
     .arp_tx_axis_tvalid		  	 (arp_to_frame_axis_tvalid	),  	 
     .arp_tx_axis_tlast		         (arp_to_frame_axis_tlast	), 
     .arp_tx_axis_tready		     (arp_to_frame_axis_tready	)

    ) ;

/* Instantiate frame tx module */	
frame_tx frame_inst
	(
	 .src_mac_addr                (src_mac_addr        ),
	 .dst_mac_addr                (dst_mac_addr        ),
	 .protocol_type 		      (protocol_type 		), 

	 .tx_axis_aclk                (tx_axis_aclk        ),
     .tx_axis_areset 		      (tx_axis_areset 		), 
     .frame_tx_axis_tdata         (frame_tx_axis_tdata ),
     .frame_tx_axis_tkeep         (frame_tx_axis_tkeep ),
     .frame_tx_axis_tvalid        (frame_tx_axis_tvalid),		 
     .frame_tx_axis_tlast         (frame_tx_axis_tlast ),
     .frame_tx_axis_tready        (frame_tx_axis_tready),		
	 .mac_tx_axis_tdata           (mac_tx_axis_tdata   ),
	 .mac_tx_axis_tkeep           (mac_tx_axis_tkeep   ),
	 .mac_tx_axis_tvalid 	      (mac_tx_axis_tvalid ), 
	 .mac_tx_axis_tlast           (mac_tx_axis_tlast   ),
     .mac_tx_axis_tready 	      (mac_tx_axis_tready ), 	
	 .rcv_stream_end              (frame_rcv_stream_end      )

    );
/* Instantiate frame tx mode module */	
frame_tx_mode frame_tx_mode_inst
       (
        .tx_axis_aclk             (tx_axis_aclk        ),
        .tx_axis_areset 	      (tx_axis_areset 	 ),

        .frame_tx_axis_tdata      (frame_tx_axis_tdata ),
        .frame_tx_axis_tkeep      (frame_tx_axis_tkeep ),
        .frame_tx_axis_tvalid     (frame_tx_axis_tvalid),		 
        .frame_tx_axis_tlast      (frame_tx_axis_tlast ),
        .frame_tx_axis_tready     (frame_tx_axis_tready),		

		.ip_tx_axis_tdata         (ip_to_frame_axis_tdata    ),
		.ip_tx_axis_tkeep         (ip_to_frame_axis_tkeep    ),
		.ip_tx_axis_tvalid 	      (ip_to_frame_axis_tvalid 	 ),
		.ip_tx_axis_tlast         (ip_to_frame_axis_tlast    ),
        .ip_tx_axis_tready 	      (ip_to_frame_axis_tready 	 ),

		.arp_tx_axis_tdata        (arp_to_frame_axis_tdata   ),
		.arp_tx_axis_tkeep        (arp_to_frame_axis_tkeep   ),
		.arp_tx_axis_tvalid       (arp_to_frame_axis_tvalid  ),
		.arp_tx_axis_tlast        (arp_to_frame_axis_tlast   ),
        .arp_tx_axis_tready   	  (arp_to_frame_axis_tready  ),
		
		.arp_not_empty			  (arp_not_empty			 ),
		.ip_not_empty			  (ip_not_empty				 ),
		.rcv_stream_end	          (frame_rcv_stream_end	     ),
		.protocol_type            (protocol_type       )
       );
	
endmodule



// IP Decryptor end

