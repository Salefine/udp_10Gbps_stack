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
//   Description:  arp cache storage, only one arp ip and mac address
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/
module arp_cache
       (
         input                clk ,
         input                rst_n ,
         
         input                arp_valid,				//arp valid signal
         input  [31:0]        arp_rcvd_src_ip_addr,		//arp received source ip address from arp rx module
         input  [47:0]        arp_rcvd_src_mac_addr,	//arp received source mac address from arp rx module
         
         input  [31:0]        dst_ip_addr,				//destination ip address, defined by user
         output reg [47:0]    dst_mac_addr,				//destination mac address
         
		 input				  arp_request_ack,			//arp request acknowledge signal
		 output	reg			  arp_request_req,			//arp request signal, when it is empty in  arp cache, assert it
		 
          output reg           mac_exist		//mac exist in arp cache
       ) ;
       
reg [79:0]  arp_cache ;		//arp cache data, combined with ip and mac address	


always @(posedge clk)
  begin
    if (~rst_n)
      arp_cache  <= 80'h00_00_00_00_ff_ff_ff_ff_ff_ff ;
    else if (arp_valid)		// if arp signal valid, record received ip and mac address in cache
      arp_cache  <= {arp_rcvd_src_ip_addr, arp_rcvd_src_mac_addr} ;
  end
  
/* check if destination ip address exist in cache */	  
always @(posedge clk)
  begin
    if (~rst_n)
	begin
      mac_exist  <= 1'b0 ;
	  dst_mac_addr  <= 48'hff_ff_ff_ff_ff_ff ;
	end
    else if (dst_ip_addr == arp_cache[79:48] && arp_cache[47:0] != 48'hff_ff_ff_ff_ff_ff)
	begin
      mac_exist  <= 1'b1 ;
	  dst_mac_addr  <= arp_cache[47:0] ;
	end
    else
	begin
      mac_exist  <= 1'b0 ;
	  dst_mac_addr  <= 48'hff_ff_ff_ff_ff_ff ;
	end
  end
 
reg [15:0]	repeat_cnt; 	//arp request repeat counter

/* arp request statement */	

localparam ARP_IDLE     	= 3'b001 ;
localparam ARP_WAIT     	= 3'b010 ;
localparam ARP_REQUEST     	= 3'b100 ;


reg [3:0]    arp_state  ;
reg [3:0]    arp_next_state ;



always @(posedge clk)
  begin
    if (~rst_n)
      arp_state  <=  ARP_IDLE  ;
    else
      arp_state  <= arp_next_state ;
  end
  
always @(*)
  begin
    case(arp_state)
      ARP_IDLE            :
        begin
          if (~mac_exist)            
			      arp_next_state <= ARP_REQUEST ;
          else
            arp_next_state <= ARP_IDLE ;
        end	
	    ARP_REQUEST            :
        begin
          if (arp_request_ack)            
			      arp_next_state <= ARP_WAIT ;
          else
            arp_next_state <= ARP_REQUEST ;
        end	
      ARP_WAIT            :
        begin
          if (mac_exist)            
            arp_next_state <= ARP_IDLE ;
          else if (repeat_cnt == 16'd50000)		//every fixed counter value, send request
            arp_next_state <= ARP_IDLE ;
          else
			      arp_next_state <= ARP_WAIT ;
        end    
	  default : arp_next_state <= ARP_IDLE ; 
	endcase
  end
/* arp request signal control */	 
always @(posedge clk)
  begin
    if (~rst_n)
      arp_request_req  <= 1'b0  ;
    else if (arp_state == ARP_IDLE && arp_state != arp_next_state)
      arp_request_req  <= 1'b1 ;
	else if (arp_request_ack)
	  arp_request_req  <= 1'b0  ;	  
  end
 /* repeat counter signal control */
  always @(posedge clk)
   begin
     if (~rst_n)
       repeat_cnt  <= 16'd0  ;
     else if (arp_state == ARP_WAIT)
       repeat_cnt  <= repeat_cnt + 1 ;
     else 
       repeat_cnt  <= 16'd0   ;      
   end
 
endmodule



// IP Decryptor end

