/****************************************************************************
 * @file    us_mac_rx_mode.v
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

module mac_rx_mode(
	input                            	    rx_axis_aclk,
	input                            	    rx_axis_aresetn,

	/* axis	interface from frame rx module  */	
	input  [63:0]       	     			frame_rx_axis_tdata,
    input  [7:0]     	     				frame_rx_axis_tkeep,
    input                            		frame_rx_axis_tvalid,		 
    input                            		frame_rx_axis_tlast,
    input                           		frame_rx_axis_tuser,
	input  [47:0]						 	rcvd_dst_mac_addr,	//received destination mac address
	input  [47:0]						 	rcvd_src_mac_addr,	//received source mac address
	input  [15:0]						 	rcvd_type,			//received type

	/* axis	interface to ip rx module  */	
	output reg [63:0]       	     		ip_rx_axis_tdata,
    output reg [7:0]     	     			ip_rx_axis_tkeep,
    output reg                           	ip_rx_axis_tvalid,		 
    output reg                           	ip_rx_axis_tlast,
    output reg                          	ip_rx_axis_tuser,

	/* axis	interface to arp rx module  */	
	output reg [63:0]       	     		arp_rx_axis_tdata,
    output reg [7:0]     	     			arp_rx_axis_tkeep,
    output reg                           	arp_rx_axis_tvalid,		 
    output reg                           	arp_rx_axis_tlast,
    output reg                          	arp_rx_axis_tuser,

	output reg [47:0]						frame_mode_dst_mac_addr,  //switched destination mac address
	output reg [47:0]						frame_mode_src_mac_addr   //switched source mac address
);


always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_aresetn)
	begin
	  ip_rx_axis_tdata    <= 64'd0 ;
	  ip_rx_axis_tkeep    <= 8'd0  ;
	  ip_rx_axis_tvalid   <= 1'b0  ;
	  ip_rx_axis_tlast    <= 1'b0  ;
	  ip_rx_axis_tuser    <= 1'b0  ;
	  arp_rx_axis_tdata   <= 64'd0 ;
	  arp_rx_axis_tkeep   <= 8'd0  ;
	  arp_rx_axis_tvalid  <= 1'b0  ;
	  arp_rx_axis_tlast   <= 1'b0  ;
	  arp_rx_axis_tuser   <= 1'b0  ;	
	  frame_mode_dst_mac_addr		  <= 48'd0 ;
	  frame_mode_src_mac_addr		  <= 48'd0 ;
	end
    else if (rcvd_type == 16'h0800)
	begin
      ip_rx_axis_tdata    <= frame_rx_axis_tdata  ;
	  ip_rx_axis_tkeep    <= frame_rx_axis_tkeep  ;
	  ip_rx_axis_tvalid   <= frame_rx_axis_tvalid ;
	  ip_rx_axis_tlast    <= frame_rx_axis_tlast  ;
	  ip_rx_axis_tuser    <= frame_rx_axis_tuser  ;
	  arp_rx_axis_tdata   <= 64'd0 ;
	  arp_rx_axis_tkeep   <= 8'd0  ;
	  arp_rx_axis_tvalid  <= 1'b0  ;
	  arp_rx_axis_tlast   <= 1'b0  ;
	  arp_rx_axis_tuser   <= 1'b0  ;
	  frame_mode_dst_mac_addr		  <= rcvd_dst_mac_addr ;
	  frame_mode_src_mac_addr		  <= rcvd_src_mac_addr ;
	end
	else if (rcvd_type == 16'h0806)
	begin
      ip_rx_axis_tdata    <= 64'd0 ;
	  ip_rx_axis_tkeep    <= 8'd0  ;
	  ip_rx_axis_tvalid   <= 1'b0  ;
	  ip_rx_axis_tlast    <= 1'b0  ;
	  ip_rx_axis_tuser     <= 1'b0  ;
	  arp_rx_axis_tdata   <= frame_rx_axis_tdata  ;
	  arp_rx_axis_tkeep   <= frame_rx_axis_tkeep  ;
	  arp_rx_axis_tvalid  <= frame_rx_axis_tvalid ;
	  arp_rx_axis_tlast   <= frame_rx_axis_tlast  ;
	  arp_rx_axis_tuser   <= frame_rx_axis_tuser  ;
	  frame_mode_dst_mac_addr		  <= rcvd_dst_mac_addr ;
	  frame_mode_src_mac_addr		  <= rcvd_src_mac_addr ;
	end
	else
	begin
	  ip_rx_axis_tdata    <= 64'd0 ;
	  ip_rx_axis_tkeep    <= 8'd0  ;
	  ip_rx_axis_tvalid   <= 1'b0  ;
	  ip_rx_axis_tlast    <= 1'b0  ;
	  ip_rx_axis_tuser     <= 1'b0  ;
	  arp_rx_axis_tdata   <= 64'd0 ;
	  arp_rx_axis_tkeep   <= 8'd0  ;
	  arp_rx_axis_tvalid  <= 1'b0  ;
	  arp_rx_axis_tlast   <= 1'b0  ;
	  arp_rx_axis_tuser   <= 1'b0  ;
	  frame_mode_dst_mac_addr		  <= 48'd0 ;
	  frame_mode_src_mac_addr		  <= 48'd0 ;	  
	end
  end

endmodule
