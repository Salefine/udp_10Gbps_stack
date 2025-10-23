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
//   Description:  frame tx mode switch module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/


module frame_tx_mode
		#(
			parameter StreamWidth = 64
		)
       (
        input                            	     tx_axis_aclk,
        input                            	     tx_axis_areset,		
		/* frame tx axis interface */
        output reg [StreamWidth-1:0]       	     frame_tx_axis_tdata,
        output reg [StreamWidth/8-1:0]     	     frame_tx_axis_tkeep,
        output reg                           	 frame_tx_axis_tvalid,		 
        output reg                           	 frame_tx_axis_tlast,
        input                           	     frame_tx_axis_tready,
		/* ip tx axis interface */
		input   [StreamWidth-1:0]       	 	 ip_tx_axis_tdata,
		input   [StreamWidth/8-1:0]     	 	 ip_tx_axis_tkeep,
		input             				     	 ip_tx_axis_tvalid,	
		input             				     	 ip_tx_axis_tlast,
        output reg             				     ip_tx_axis_tready,
		
		/* arp tx axis interface */
		input   [StreamWidth-1:0]       	 	 arp_tx_axis_tdata,
		input   [StreamWidth/8-1:0]     	 	 arp_tx_axis_tkeep,
		input             				     	 arp_tx_axis_tvalid,	
		input             				     	 arp_tx_axis_tlast,
        output reg             				     arp_tx_axis_tready,
		
		input                   				 ip_not_empty,		//ip data is ready to send
		input                   				 arp_not_empty,		//arp data is ready to send
		input								     rcv_stream_end	,	//receive stream end signal
		output reg [15:0]						 protocol_type		//ip protocol: 16'h0800; arp protocol: 16'h0806
       );
       
localparam ip_type  = 16'h0800 ;   
localparam arp_type = 16'h0806 ;     
       

localparam IDLE       = 3'b001 ;
localparam ARP        = 3'b010 ;
localparam IP         = 3'b100 ;


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
          if (arp_not_empty)
            next_state <= ARP ;
          else if (ip_not_empty)
            next_state <= IP  ;
          else
            next_state <= IDLE ;
        end
      ARP         :
        begin
          if (rcv_stream_end)
            next_state <= IDLE ;
          else
            next_state <= ARP ;
        end
      IP          :
        begin
          if (rcv_stream_end)
            next_state <= IDLE ;
          else
            next_state <= IP ;
        end
      default     :
        next_state <= IDLE ;
    endcase
  end
   


always @(*)
  begin
    if (state == IP)
      begin
        frame_tx_axis_tdata     <= ip_tx_axis_tdata  ;
        frame_tx_axis_tkeep     <= ip_tx_axis_tkeep  ;
        frame_tx_axis_tvalid	<= ip_tx_axis_tvalid ;
        frame_tx_axis_tlast     <= ip_tx_axis_tlast  ;
		ip_tx_axis_tready	 	<= frame_tx_axis_tready  ;
		arp_tx_axis_tready  	<= 1'b0 ;
		protocol_type		 	<= ip_type ;
      end
    else if (state == ARP)
      begin
        frame_tx_axis_tdata     <= arp_tx_axis_tdata  ;
        frame_tx_axis_tkeep     <= arp_tx_axis_tkeep  ;
        frame_tx_axis_tvalid	<= arp_tx_axis_tvalid ;
        frame_tx_axis_tlast     <= arp_tx_axis_tlast  ;
		arp_tx_axis_tready	 	<= frame_tx_axis_tready  ; 
		ip_tx_axis_tready    	<= 1'b0 ;	
		protocol_type		 	<= arp_type ;		
      end
    else
      begin
        frame_tx_axis_tdata     <= 64'd0  ;
        frame_tx_axis_tkeep     <= 8'd0  ;
        frame_tx_axis_tvalid	<= 1'b0 ;
        frame_tx_axis_tlast     <= 1'b0  ;
		ip_tx_axis_tready	 	<= 1'b0  ;
		arp_tx_axis_tready  	<= 1'b0 ;
		protocol_type		 	<= ip_type ;
      end
  end  
  
endmodule



// IP Decryptor end

