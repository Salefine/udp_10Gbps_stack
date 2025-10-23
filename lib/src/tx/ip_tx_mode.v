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
//   Description:  ip transmit mode switch module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/
`timescale 1 ns/1 ns
module ip_tx_mode
       (
		 input                			tx_axis_aclk,
         input                			tx_axis_areset,  
		 /* ip tx axis interface */	
		 output reg [63:0]        		ip_tx_axis_tdata,
         output reg [7:0]     	  		ip_tx_axis_tkeep,
         output reg               		ip_tx_axis_tvalid,		 
         output reg               		ip_tx_axis_tlast,
         input 	  	         			ip_tx_axis_tready,
         /* udp tx axis interface */	
		 input  [63:0]       			udp_tx_axis_tdata,
         input  [7:0]     				udp_tx_axis_tkeep,
         input                          udp_tx_axis_tvalid,
         input                          udp_tx_axis_tlast,
         output reg                     udp_tx_axis_tready,
		 /* icmp tx axis interface */	
		 input  [63:0]       			icmp_tx_axis_tdata,
         input  [7:0]     				icmp_tx_axis_tkeep,
         input                          icmp_tx_axis_tvalid,
         input                          icmp_tx_axis_tlast,
         output reg                     icmp_tx_axis_tready,
		 
		 input                   		udp_not_empty,		//udp data is ready to send
		 input                   		icmp_not_empty,     //icmp data is ready to send
         output reg [7:0]        		ip_send_type,       //udp protocol: 8'h11; icmp protocol: 8'h01
		 input							rcv_stream_end      //receive stream end signal
       );
       
localparam ip_udp_type  = 8'h11 ;
localparam ip_icmp_type = 8'h01 ;


parameter IDLE      = 3'b001 ;
parameter UDP       = 3'b010 ;
parameter ICMP      = 3'b100 ;


reg [2:0]    state  ;
reg [2:0]    next_state ;

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
      IDLE        :
        begin
		  if (icmp_not_empty)
            next_state <= ICMP ;
      else if (udp_not_empty)
            next_state <= UDP ;         
      else
            next_state <= IDLE ;
        end
      UDP         :
        begin
          if (rcv_stream_end)
            next_state <= IDLE ;
          else
            next_state <= UDP ;
        end
      ICMP        :
        begin
          if (rcv_stream_end)
            next_state <= IDLE ;
          else
            next_state <= ICMP ;
        end
      default     :
        next_state <= IDLE ;
    endcase
  end
  
   
  
always @(*)
  begin
    if (state == UDP)
      begin
        ip_tx_axis_tdata     <= udp_tx_axis_tdata  ;
        ip_tx_axis_tkeep     <= udp_tx_axis_tkeep  ;
        ip_tx_axis_tvalid	 <= udp_tx_axis_tvalid ;
        ip_tx_axis_tlast     <= udp_tx_axis_tlast  ;
		udp_tx_axis_tready	 <= ip_tx_axis_tready  ;
		icmp_tx_axis_tready  <= 1'b0 ;
		ip_send_type		 <= ip_udp_type ;
      end
    else if (state == ICMP)
      begin
        ip_tx_axis_tdata     <= icmp_tx_axis_tdata  ;
        ip_tx_axis_tkeep     <= icmp_tx_axis_tkeep  ;
        ip_tx_axis_tvalid	 <= icmp_tx_axis_tvalid ;
        ip_tx_axis_tlast     <= icmp_tx_axis_tlast  ;
		icmp_tx_axis_tready	 <= ip_tx_axis_tready  ; 
		udp_tx_axis_tready   <= 1'b0 ;	
		ip_send_type		 <= ip_icmp_type ;		
      end
    else
      begin
        ip_tx_axis_tdata     <= 64'd0  ;
        ip_tx_axis_tkeep     <= 8'd0   ;
        ip_tx_axis_tvalid	 <= 1'b0   ;
        ip_tx_axis_tlast     <= 1'b0   ;
		udp_tx_axis_tready	 <= 1'b0   ;
		icmp_tx_axis_tready  <= 1'b0   ;
		ip_send_type		 <= ip_udp_type ;
      end
  end
  
  
  
endmodule





// IP Decryptor end

