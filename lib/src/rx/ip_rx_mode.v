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
//   Description:  ip receive mode switch module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/


module ip_rx_mode
	(
		input                            	    rx_axis_aclk,
		input                            	    rx_axis_areset,
		/* ip rx axis interface */
		input  [63:0]       	     			ip_rx_axis_tdata,
        input  [7:0]     	     				ip_rx_axis_tkeep,
        input                            		ip_rx_axis_tvalid,		 
        input                            		ip_rx_axis_tlast,
        input                           		ip_rx_axis_tusr,
		
		input  [31:0]						 	rcvd_dst_ip_addr,
		input  [31:0]						 	rcvd_src_ip_addr,
		input  [7:0]						 	rcvd_type,
		/* udp rx axis interface */
		output reg [63:0]       	     		udp_rx_axis_tdata,
        output reg [7:0]     	     			udp_rx_axis_tkeep,
        output reg                           	udp_rx_axis_tvalid,		 
        output reg                           	udp_rx_axis_tlast,
        output reg                          	udp_rx_axis_tusr,
		/* icmp rx axis interface */
		output reg [63:0]       	     		icmp_rx_axis_tdata,
        output reg [7:0]     	     			icmp_rx_axis_tkeep,
        output reg                           	icmp_rx_axis_tvalid,		 
        output reg                           	icmp_rx_axis_tlast,
        output reg                          	icmp_rx_axis_tusr,
		
		output reg [31:0]						ip_mode_dst_ip_addr,
		output reg [31:0]						ip_mode_src_ip_addr
    );
	
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
	  udp_rx_axis_tdata    <= 64'd0 ;
	  udp_rx_axis_tkeep    <= 8'd0  ;
	  udp_rx_axis_tvalid   <= 1'b0  ;
	  udp_rx_axis_tlast    <= 1'b0  ;
	  udp_rx_axis_tusr     <= 1'b0  ;
	  icmp_rx_axis_tdata   <= 64'd0 ;
	  icmp_rx_axis_tkeep   <= 8'd0  ;
	  icmp_rx_axis_tvalid  <= 1'b0  ;
	  icmp_rx_axis_tlast   <= 1'b0  ;
	  icmp_rx_axis_tusr    <= 1'b0  ;	
	  ip_mode_dst_ip_addr		  <= 32'd0 ;
	  ip_mode_src_ip_addr		  <= 32'd0 ;
	end
    else if (rcvd_type == 8'h11)
	begin
      udp_rx_axis_tdata    <= ip_rx_axis_tdata  ;
	  udp_rx_axis_tkeep    <= ip_rx_axis_tkeep  ;
	  udp_rx_axis_tvalid   <= ip_rx_axis_tvalid ;
	  udp_rx_axis_tlast    <= ip_rx_axis_tlast  ;
	  udp_rx_axis_tusr     <= ip_rx_axis_tusr   ;
	  icmp_rx_axis_tdata   <= 64'd0 ;
	  icmp_rx_axis_tkeep   <= 8'd0  ;
	  icmp_rx_axis_tvalid  <= 1'b0  ;
	  icmp_rx_axis_tlast   <= 1'b0  ;
	  icmp_rx_axis_tusr    <= 1'b0  ;
	  ip_mode_dst_ip_addr		  <= rcvd_dst_ip_addr ;
	  ip_mode_src_ip_addr		  <= rcvd_src_ip_addr ;
	end
	else if (rcvd_type == 8'h01)
	begin
      udp_rx_axis_tdata    <= 64'd0 ;
	  udp_rx_axis_tkeep    <= 8'd0  ;
	  udp_rx_axis_tvalid   <= 1'b0  ;
	  udp_rx_axis_tlast    <= 1'b0  ;
	  udp_rx_axis_tusr     <= 1'b0  ;
	  icmp_rx_axis_tdata   <= ip_rx_axis_tdata  ;
	  icmp_rx_axis_tkeep   <= ip_rx_axis_tkeep  ;
	  icmp_rx_axis_tvalid  <= ip_rx_axis_tvalid ;
	  icmp_rx_axis_tlast   <= ip_rx_axis_tlast  ;
	  icmp_rx_axis_tusr    <= ip_rx_axis_tusr   ;
	  ip_mode_dst_ip_addr		  <= rcvd_dst_ip_addr ;
	  ip_mode_src_ip_addr		  <= rcvd_src_ip_addr ;
	end
	else
	begin
	  udp_rx_axis_tdata    <= 64'd0 ;
	  udp_rx_axis_tkeep    <= 8'd0  ;
	  udp_rx_axis_tvalid   <= 1'b0  ;
	  udp_rx_axis_tlast    <= 1'b0  ;
	  udp_rx_axis_tusr     <= 1'b0  ;
	  icmp_rx_axis_tdata   <= 64'd0 ;
	  icmp_rx_axis_tkeep   <= 8'd0  ;
	  icmp_rx_axis_tvalid  <= 1'b0  ;
	  icmp_rx_axis_tlast   <= 1'b0  ;
	  icmp_rx_axis_tusr    <= 1'b0  ;
	  ip_mode_dst_ip_addr		  <= 32'd0 ;	 
	  ip_mode_src_ip_addr		  <= 32'd0 ;	  
	end
  end
  
endmodule



// IP Decryptor end

