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
//   Description:  ip layer receive module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/


module ip_rx(
		input                           rx_axis_aclk,
		input                           rx_axis_areset,
		/* frame rx axis interface */
		input [63:0]       	     		frame_rx_axis_tdata,
        input [7:0]     	     		frame_rx_axis_tkeep,
        input                          	frame_rx_axis_tvalid,		 
        input                         	frame_rx_axis_tlast,
        input                          	frame_rx_axis_tusr,
		/* ip rx axis interface */
		output  [63:0]       	   	    ip_rx_axis_tdata,
        output  [7:0]     	     	    ip_rx_axis_tkeep,
        output                          ip_rx_axis_tvalid,		 
        output                          ip_rx_axis_tlast,
        output                          ip_rx_axis_tusr,
		
		input [31:0]					local_ip_addr,		//local ip address
		input [47:0]					local_mac_addr,     //local mac address
		input [47:0]					rcvd_dst_mac_addr,  //received destination mac address
		output reg [7:0]				ip_type,            //received ip type, icmp or udp
		output reg [31:0]				rcvd_dst_ip_addr,   //received destination ip address
		output reg [31:0]				rcvd_src_ip_addr    //received source ip address
    );


reg [7:0]					head_length ;		//head length
reg [15:0]					ip_data_length ;	//ip data length with ip head
reg [15:0]					ip_head_checksum ;	//ip head checksum


reg  [63:0]					rcvd_data;			//received data
reg  [63:0]					rcvd_data_dly;		//received data register
wire [63:0]					valid_data ;		//combined valid data

/* ip rx statement */	
localparam IP_RCV_WORD_1ST      = 6'b000001 ;	//receive first word
localparam IP_RCV_WORD_2ND      = 6'b000010 ;   //receive second word
localparam IP_RCV_WORD_3RD      = 6'b000100 ;   //receive third word
localparam IP_RCV_WORD_DATA    	= 6'b001000 ;   //receive data word
localparam IP_RCV_GOOD     		= 6'b010000 ;   //receive good frame
localparam IP_RCV_BAD     		= 6'b100000 ;   //receive bad frame


reg [5:0]    rcv_state  ;
reg [5:0]    rcv_next_state ;



always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcv_state  <=  IP_RCV_WORD_1ST  ;
    else
      rcv_state  <= rcv_next_state ;
  end
  
always @(*)
  begin
    case(rcv_state)
      IP_RCV_WORD_1ST            :
        begin
          if (frame_rx_axis_tvalid & ~frame_rx_axis_tlast)
            rcv_next_state <= IP_RCV_WORD_2ND ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= IP_RCV_BAD ;
          else
            rcv_next_state <= IP_RCV_WORD_1ST ;
        end		
	  IP_RCV_WORD_2ND   :
		begin
          if (frame_rx_axis_tvalid & ~frame_rx_axis_tlast)
            rcv_next_state <= IP_RCV_WORD_3RD ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= IP_RCV_BAD ;
          else
            rcv_next_state <= IP_RCV_WORD_2ND ;
        end		
	  IP_RCV_WORD_3RD   :
		begin
          if (frame_rx_axis_tvalid & ~frame_rx_axis_tlast)
            rcv_next_state <= IP_RCV_WORD_DATA ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= IP_RCV_BAD ;
          else
            rcv_next_state <= IP_RCV_WORD_3RD ;
        end		
	  IP_RCV_WORD_DATA     :
        begin
          if (frame_rx_axis_tvalid & frame_rx_axis_tlast & frame_rx_axis_tusr)
            rcv_next_state <= IP_RCV_GOOD ;
		  else if (frame_rx_axis_tvalid & frame_rx_axis_tlast & ~frame_rx_axis_tusr)
            rcv_next_state <= IP_RCV_BAD ;
          else
            rcv_next_state <= IP_RCV_WORD_DATA ; 	
        end
	  IP_RCV_GOOD      :
        rcv_next_state <= IP_RCV_WORD_1ST ;
	  IP_RCV_BAD     :
        rcv_next_state <= IP_RCV_WORD_1ST ;
      default        :
        rcv_next_state <= IP_RCV_WORD_1ST ;
    endcase
  end  	



/* received IP length */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
      head_length  <=  4'd0  ;
	  ip_data_length <= 16'd0 ;
	end
    else if (rcv_state == IP_RCV_WORD_1ST && frame_rx_axis_tvalid)
	begin
      head_length  <= frame_rx_axis_tdata[3:0] ;
	  ip_data_length[7:0] <= frame_rx_axis_tdata[31:24] ;
	  ip_data_length[15:8] <= frame_rx_axis_tdata[23:16] ;
	end
  end

/* received IP head length */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
      ip_type  <=  8'd0  ;
	  ip_head_checksum <= 16'd0 ;
	  rcvd_src_ip_addr <= 32'd0 ;
	end
    else if (rcv_state == IP_RCV_WORD_2ND && frame_rx_axis_tvalid)
    begin
      ip_type  <=  frame_rx_axis_tdata[15:8]   ;
	  ip_head_checksum[7:0] <= frame_rx_axis_tdata[31:24] ;
	  ip_head_checksum[15:8] <= frame_rx_axis_tdata[23:16] ;
	  rcvd_src_ip_addr[31:24] <= frame_rx_axis_tdata[39:32] ;
	  rcvd_src_ip_addr[23:16] <= frame_rx_axis_tdata[47:40] ;
	  rcvd_src_ip_addr[15:8] <= frame_rx_axis_tdata[55:48] ;
	  rcvd_src_ip_addr[7:0] <= frame_rx_axis_tdata[63:56] ;
	end
  end
/* received destination ip address */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
	  rcvd_dst_ip_addr <= 32'd0 ;
	end
    else if (rcv_state == IP_RCV_WORD_3RD && frame_rx_axis_tvalid)
    begin
	  rcvd_dst_ip_addr[31:24] <= frame_rx_axis_tdata[7:0] ;
	  rcvd_dst_ip_addr[23:16] <= frame_rx_axis_tdata[15:8] ;
	  rcvd_dst_ip_addr[15:8] <= frame_rx_axis_tdata[23:16] ;
	  rcvd_dst_ip_addr[7:0] <= frame_rx_axis_tdata[31:24] ;
	end
  end

/* received data */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
		rcvd_data <= 64'd0 ;
    else if (rcv_state == IP_RCV_WORD_3RD && frame_rx_axis_tvalid )
		rcvd_data[31:0] <= frame_rx_axis_tdata[63:32] ;
	else if (rcv_state == IP_RCV_WORD_DATA && frame_rx_axis_tvalid)
	begin
		rcvd_data[31:0] <= frame_rx_axis_tdata[63:32] ;
		rcvd_data[63:32] <= frame_rx_axis_tdata[31:0] ;
	end
  end

/* data register */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
		rcvd_data_dly <= 64'd0 ;
    else if (rcv_state == IP_RCV_WORD_3RD || rcv_state == IP_RCV_WORD_DATA || rcv_state == IP_RCV_GOOD || rcv_state == IP_RCV_BAD)
		rcvd_data_dly <= rcvd_data ;
  end
/* combined valid data */
assign valid_data = {rcvd_data[63:32], rcvd_data_dly[31:0]} ;



//****************************************************************//
//verify checksum
//****************************************************************//
reg  [31:0] checksum_tmp0 ;
reg  [31:0] checksum_tmp1 ;
reg  [31:0] checksum_tmp2 ;
reg  [31:0] checksum_tmp3 ;
reg  [31:0] checksum_tmp4 ;
reg  [31:0] checksum_tmp5 ;
reg  [31:0] checksum_tmp6 ;
reg  [31:0] checksum_tmp7 ;
reg  [31:0] checksum_tmp8 ;
reg  [31:0] checksum_buf ;
wire [15:0] checksum ;



//checksum function
function    [31:0]  checksum_adder
  (
    input       [31:0]  dataina,
    input       [31:0]  datainb
  );
  
  begin
    checksum_adder = dataina + datainb;
  end
endfunction

function    [31:0]  checksum_out
  (
    input      [31:0]  dataina
  );
  
  begin
    checksum_out = dataina[15:0]+dataina[31:16];
  end
  
endfunction

/* ip head checksum calculation */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		checksum_tmp0 <= 32'd0 ;
		checksum_tmp1 <= 32'd0 ;
		checksum_tmp2 <= 32'd0 ;
		checksum_tmp3 <= 32'd0 ;
		checksum_tmp4 <= 32'd0 ;
		checksum_tmp5 <= 32'd0 ;
		checksum_tmp6 <= 32'd0 ;
	end
	else if ((rcv_state == IP_RCV_WORD_1ST || rcv_state == IP_RCV_WORD_2ND)  && frame_rx_axis_tvalid)
	begin
		checksum_tmp0  <= checksum_adder({frame_rx_axis_tdata[7:0],frame_rx_axis_tdata[15:8]}, checksum_tmp0);		  
		checksum_tmp1  <= checksum_adder({frame_rx_axis_tdata[23:16],frame_rx_axis_tdata[31:24]}, checksum_tmp1);
		checksum_tmp2  <= checksum_adder({frame_rx_axis_tdata[39:32],frame_rx_axis_tdata[47:40]}, checksum_tmp2);
		checksum_tmp3  <= checksum_adder({frame_rx_axis_tdata[55:48],frame_rx_axis_tdata[63:56]}, checksum_tmp3);
	end
/* 	else if (rcv_state == IP_RCV_WORD_2ND && frame_rx_axis_tvalid)
	begin
		checksum_tmp0  <= checksum_adder({frame_rx_axis_tdata[7:0],frame_rx_axis_tdata[15:8]}, checksum_tmp0);		  
		checksum_tmp1  <= checksum_adder({frame_rx_axis_tdata[23:16],frame_rx_axis_tdata[31:24]}, checksum_tmp1);
		checksum_tmp2  <= checksum_adder({frame_rx_axis_tdata[39:32],frame_rx_axis_tdata[47:40]}, checksum_tmp2);
		checksum_tmp3  <= checksum_adder({frame_rx_axis_tdata[55:48],frame_rx_axis_tdata[63:56]}, checksum_tmp3);
	end */
	else if (rcv_state == IP_RCV_WORD_3RD && frame_rx_axis_tvalid)
	begin
		checksum_tmp4  <= checksum_adder({frame_rx_axis_tdata[7:0],frame_rx_axis_tdata[15:8]}, {frame_rx_axis_tdata[23:16],frame_rx_axis_tdata[31:24]});	
		checksum_tmp5  <= checksum_adder(checksum_tmp0, checksum_tmp1);
		checksum_tmp6  <= checksum_adder(checksum_tmp2, checksum_tmp3);
		checksum_tmp0  <= 32'd0 ;	  
		checksum_tmp1  <= 32'd0 ;
		checksum_tmp2  <= 32'd0 ;
		checksum_tmp3  <= 32'd0 ;
	end
  end
  
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		checksum_tmp7 <= 32'd0 ;
		checksum_tmp8 <= 32'd0 ;
	end
	else 
	begin
		checksum_tmp7  <= checksum_adder(checksum_tmp4, checksum_tmp5);
		checksum_tmp8  <= checksum_adder(checksum_tmp6, checksum_tmp7);
	end
  end 
  
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      checksum_buf <= 32'd0;
    else
      checksum_buf <= checksum_out(checksum_tmp8) ;
  end
/* checksum reversion */ 
assign checksum = ~checksum_buf[15:0] ; 



/**************************************************************
frame rx storage 
**************************************************************/
reg  [7:0]				frame_rx_axis_tkeep_dly ;
reg						frame_rx_axis_tusr_dly ;

wire [63:0]       	   	 ip_tdata;
reg [7:0]     	     	 ip_tkeep;
reg                      ip_tvalid;		 
reg                      ip_tlast;
reg                      ip_tusr;

assign ip_tdata = valid_data ;
/* frame tkeep and tusr register */ 
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
      frame_rx_axis_tkeep_dly  <=  8'd0  ;
	  frame_rx_axis_tusr_dly <= 1'b0 ;
	end
    else 
	begin
      frame_rx_axis_tkeep_dly  <= frame_rx_axis_tkeep ;
	  frame_rx_axis_tusr_dly <= frame_rx_axis_tusr ;
	end
  end
/* ip tvalid control, if received destination ip address not equals to loacl ip address and reveived mac address not equals to local mac address, tvalid is false, 
	or if last word bigger than 4, which means there is additinal one word in the last */ 
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
		ip_tvalid  <=  1'b0  ;
	else if (rcvd_dst_ip_addr != local_ip_addr || rcvd_dst_mac_addr != local_mac_addr)
		ip_tvalid  <=  1'b0  ;
    else if (rcv_state == IP_RCV_WORD_DATA && frame_rx_axis_tvalid)
		ip_tvalid  <= 1'b1 ;
	else if (rcv_state == IP_RCV_GOOD || rcv_state == IP_RCV_BAD)
	begin
		if (frame_rx_axis_tkeep_dly == 8'hff || frame_rx_axis_tkeep_dly == 8'h7f || frame_rx_axis_tkeep_dly == 8'h3f || frame_rx_axis_tkeep_dly == 8'h1f)
			ip_tvalid  <= 1'b1 ;
		else
			ip_tvalid  <= 1'b0 ;
	end
	else
		ip_tvalid  <= 1'b0 ;
  end	
/* frame tlast, tusr, tkeep control, if received destination ip address not equals to loacl ip address and reveived mac address not equals to local mac address, they are false */ 
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		ip_tlast  <=  1'b0  ;
		ip_tusr   <= 1'b0 ;
		ip_tkeep  <= 8'h00 ;
	end
	else if (rcvd_dst_ip_addr != local_ip_addr || rcvd_dst_mac_addr != local_mac_addr)
	begin
		ip_tlast  <=  1'b0  ;
		ip_tusr   <= 1'b0 ;
		ip_tkeep  <= 8'h00 ;
	end
	else if (rcv_state == IP_RCV_WORD_DATA && rcv_state == rcv_next_state)
	begin
		ip_tlast  <= 1'b0 ;
		ip_tusr   <= 1'b0 ;
		ip_tkeep  <= 8'hff ;
	end
    else if (rcv_state == IP_RCV_WORD_DATA && rcv_state != rcv_next_state)
	begin
		if (frame_rx_axis_tkeep == 8'hff || frame_rx_axis_tkeep == 8'h7f || frame_rx_axis_tkeep == 8'h3f || frame_rx_axis_tkeep == 8'h1f)
		begin
			ip_tlast  <= 1'b0 ;
			ip_tusr   <= 1'b0 ;
			ip_tkeep  <= 8'hff ;
		end
		else
		begin
			ip_tlast  <= 1'b1 ;
			ip_tusr   <= frame_rx_axis_tusr ;
			ip_tkeep  <= {frame_rx_axis_tkeep[5:0],4'hf} ;
		end
	end
	else if (rcv_state == IP_RCV_GOOD || rcv_state == IP_RCV_BAD)
	begin
		if (ip_tlast)
		begin
			ip_tlast  <= 1'b0 ;
			ip_tusr   <= 1'b0 ;
			ip_tkeep  <= 8'h00 ;
		end
		else
		begin
			ip_tlast  <= 1'b1 ;
			ip_tusr   <= frame_rx_axis_tusr_dly ;
			ip_tkeep  <= frame_rx_axis_tkeep_dly>>4 ;
		end
	end
	else
	begin
		ip_tlast  <= 1'b0 ;
		ip_tusr   <= 1'b0 ;
		ip_tkeep  <= 8'h00 ;
	end
  end	

/**************************************************************
Checksum check
**************************************************************/
localparam DlyLength = 3 ;

reg [63:0]       	   	      ip_tdata_dly [DlyLength-1:0];
reg [7:0]     	     	      ip_tkeep_dly [DlyLength-1:0];
reg [DlyLength-1:0]                     ip_tvalid_dly ;	
reg [DlyLength-1:0]                     ip_tlast_dly;
reg [DlyLength-1:0]                     ip_tusr_dly;


genvar i ;
generate	
	for(i = 0 ;i < DlyLength; i=i+1)
	begin : shifter
		always @(posedge rx_axis_aclk)
		begin
			if (~rx_axis_areset)
			begin
				ip_tdata_dly[i] 	<= 64'd0 ;
				ip_tkeep_dly[i] 	<= 8'd0 ;
				ip_tvalid_dly[i]   	<= 1'b0 ;
				ip_tlast_dly[i]    	<= 1'b0 ;	
				ip_tusr_dly[i]     	<= 1'b0 ;					
			end
			else
			begin
				ip_tdata_dly[i] 	<= (i == 0)? ip_tdata : ip_tdata_dly[i-1] ;
				ip_tkeep_dly[i] 	<= (i == 0)? ip_tkeep : ip_tkeep_dly[i-1] ;
				ip_tvalid_dly[i] 	<= (i == 0)? ip_tvalid : ip_tvalid_dly[i-1] ;
				ip_tlast_dly[i] 	<= (i == 0)? ip_tlast : ip_tlast_dly[i-1] ;
				
				if (i == 0)
					ip_tusr_dly[i] <= ip_tusr ;
				else if (i == DlyLength-1)
				begin
					if (checksum == 16'd0)				// check received checksum to determine tusr
						ip_tusr_dly[i] <= ip_tusr_dly[i-1] ;
					else
						ip_tusr_dly[i] <= 0 ;
				end
				else
					ip_tusr_dly[i] <= ip_tusr_dly[i-1] ;
				
			end
		end
	end
endgenerate


assign ip_rx_axis_tdata     =  ip_tdata_dly[DlyLength-1] ;
assign ip_rx_axis_tkeep     =  ip_tkeep_dly[DlyLength-1] ; 
assign ip_rx_axis_tvalid    =  ip_tvalid_dly[DlyLength-1] ;
assign ip_rx_axis_tlast		=  ip_tlast_dly[DlyLength-1] ;	 		
assign ip_rx_axis_tusr		=  ip_tusr_dly[DlyLength-1] ;	 	




endmodule



// IP Decryptor end

