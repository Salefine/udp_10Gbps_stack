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
//   Description:  udp layer receive module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//  2020/12/16    myj          1.0         support jumbo frame
//********************************************************************************/


module udp_rx(
		input                           rx_axis_aclk,
		input                           rx_axis_areset,
		/* ip rx axis interface */
		input [63:0]       	     		ip_rx_axis_tdata,
        input [7:0]     	     		ip_rx_axis_tkeep,
        input                           ip_rx_axis_tvalid,		 
        input                           ip_rx_axis_tlast,
        input                          	ip_rx_axis_tusr,
		/* udp rx axis interface */
		output reg [63:0]       	   	udp_rx_axis_tdata,
        output reg [7:0]     	     	udp_rx_axis_tkeep,
        output reg                      udp_rx_axis_tvalid,		 
        output reg                      udp_rx_axis_tlast,
        output reg                      udp_rx_axis_tusr,
		
		input [31:0]					rcvd_dst_ip_addr,	//received destination ip address, for checksum use
		input [31:0]					rcvd_src_ip_addr    //received source ip address, for checksum use
    );


reg [15:0]					rcvd_checksum ;			//received checksum
reg [15:0]					rcvd_src_port ;	        //received source port
reg [15:0]					rcvd_dst_port ;	        //received source port
reg [15:0]					rcvd_data_length ;	    //received udp data length

/* udp axis interface */
reg [63:0]       	     		udp_tdata ;
reg [7:0]     	     			udp_tkeep ;
reg                           	udp_tvalid ;		 
reg                           	udp_tlast ;
reg                          	udp_tusr  ;
/* udp rx statement */		
localparam UDP_RCV_HEAD      	= 4'b0001 ;
localparam UDP_RCV_DATA    		= 4'b0010 ;
localparam UDP_RCV_GOOD     	= 4'b0100 ;
localparam UDP_RCV_BAD     		= 4'b1000 ;


reg [3:0]    rcv_state  ;
reg [3:0]    rcv_next_state ;



always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcv_state  <=  UDP_RCV_HEAD  ;
    else
      rcv_state  <= rcv_next_state ;
  end
  
always @(*)
  begin
    case(rcv_state)
      UDP_RCV_HEAD            :
        begin
          if (ip_rx_axis_tvalid & ~ip_rx_axis_tlast)
            rcv_next_state <= UDP_RCV_DATA ;
		  else if (ip_rx_axis_tvalid & ip_rx_axis_tlast)	//if tvalid and tlast high in the same time now, it is bad frame
			rcv_next_state <= UDP_RCV_BAD ;
          else
            rcv_next_state <= UDP_RCV_HEAD ;
        end		
	  UDP_RCV_DATA     :
        begin
          if (ip_rx_axis_tvalid & ip_rx_axis_tlast & ip_rx_axis_tusr)
            rcv_next_state <= UDP_RCV_GOOD ;
		  else if (ip_rx_axis_tvalid & ip_rx_axis_tlast & ~ip_rx_axis_tusr)
            rcv_next_state <= UDP_RCV_BAD ;
          else
            rcv_next_state <= UDP_RCV_DATA ; 	
        end
	  UDP_RCV_GOOD      :
        rcv_next_state <= UDP_RCV_HEAD ;
	  UDP_RCV_BAD     :
        rcv_next_state <= UDP_RCV_HEAD ;
      default        :
        rcv_next_state <= UDP_RCV_HEAD ;
    endcase
  end  	

/* received source port, destination port, udp data length, udp checksum */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		rcvd_src_port  	 <= 16'd0 ;
		rcvd_dst_port 	 <= 16'd0 ;
		rcvd_data_length <= 16'd0 ;
		rcvd_checksum    <= 16'd0 ;
	end
	else if (rcv_state == UDP_RCV_HEAD  && ip_rx_axis_tvalid)
	begin
		rcvd_src_port[15:8]  	 <= ip_rx_axis_tdata[7:0] ;
		rcvd_src_port[7:0]  	 <= ip_rx_axis_tdata[15:8] ;
		rcvd_dst_port[15:8]  	 <= ip_rx_axis_tdata[23:16] ;
		rcvd_dst_port[7:0]  	 <= ip_rx_axis_tdata[31:24] ;
		rcvd_data_length[15:8]   <= ip_rx_axis_tdata[39:32] ;
		rcvd_data_length[7:0]  	 <= ip_rx_axis_tdata[47:40] ;
		rcvd_checksum[15:8]  	 <= ip_rx_axis_tdata[55:48] ;
		rcvd_checksum[7:0]  	 <= ip_rx_axis_tdata[63:56] ;
	end
  end
  
/* udp interface register */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		udp_tdata  <= 64'd0 ;
		udp_tkeep  <= 8'd0 ;
		udp_tvalid <= 1'b0 ;
		udp_tlast  <= 1'b0 ;
		udp_tusr   <= 1'b0  ;
	end
	else if (rcv_state == UDP_RCV_DATA  && ip_rx_axis_tvalid)
	begin
		udp_tdata  <= ip_rx_axis_tdata ;
		udp_tkeep  <= ip_rx_axis_tkeep;
		udp_tvalid <= ip_rx_axis_tvalid;
		udp_tlast  <= ip_rx_axis_tlast;
		udp_tusr   <= ip_rx_axis_tusr ;
	end
	else
	begin
		udp_tdata  <= 64'd0 ;
		udp_tkeep  <= 8'd0 ;
		udp_tvalid <= 1'b0 ;
		udp_tlast  <= 1'b0 ;
		udp_tusr   <= 1'b0  ;
	end
  end

//****************************************************************//
//verify checksum
//****************************************************************//
reg  [16:0] checksum_tmp0 ;
reg  [16:0] checksum_tmp1 ;
reg  [16:0] checksum_tmp2 ;
reg  [16:0] checksum_tmp3 ;
reg  [16:0] checksum_tmp15 ;

reg  [31:0] checksum_tmp4 ;
reg  [31:0] checksum_tmp5 ;
reg  [31:0] checksum_tmp6 ;
reg  [31:0] checksum_tmp7 ;
reg  [17:0] checksum_tmp8 ;
reg  [17:0] checksum_tmp9 ;
reg  [18:0] checksum_tmp10 ;
reg  [19:0] checksum_tmp16 ;
 reg  [31:0] checksum_tmp11 ;
 reg  [31:0] checksum_tmp12 ;
 reg  [31:0] checksum_tmp13 ;
 reg  [31:0] checksum_tmp14 ;
 reg  [31:0] checksum_buf ;
 reg  [31:0] checksum_buf_dly ;
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

/* udp data checksum calculation */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		checksum_tmp0 <= 17'd0 ;
		checksum_tmp1 <= 17'd0 ;
		checksum_tmp2 <= 17'd0 ;
		checksum_tmp3 <= 17'd0 ;
		checksum_tmp4 <= 32'd0 ;
		checksum_tmp5 <= 32'd0 ;
		checksum_tmp6 <= 32'd0 ;
		checksum_tmp7 <= 32'd0 ;
		checksum_tmp15 <= 17'd0 ;
	end
	else if (rcv_state == UDP_RCV_HEAD  && ip_rx_axis_tvalid)
	begin
		checksum_tmp0 <= 17'd0 ;
		checksum_tmp1 <= 17'd0 ;
		checksum_tmp2 <= 17'd0 ;
		checksum_tmp3 <= 17'd0 ;
		checksum_tmp4 <= 32'd0 ;
		checksum_tmp5 <= 32'd0 ;
		checksum_tmp6 <= 32'd0 ;
		checksum_tmp7 <= 32'd0 ;
		checksum_tmp15 <= 17'd0 ;
	end
	else if (rcv_state == UDP_RCV_DATA  && ip_rx_axis_tvalid)
	begin
		checksum_tmp0 <= checksum_adder(rcvd_src_ip_addr[15:0], rcvd_src_ip_addr[31:16]) ;
		checksum_tmp1 <= checksum_adder(rcvd_dst_ip_addr[15:0], rcvd_dst_ip_addr[31:16]) ;
		checksum_tmp2 <= checksum_adder({8'd0,8'h11},rcvd_data_length) ;
		checksum_tmp3 <= checksum_adder(rcvd_src_port,rcvd_dst_port) ;
		checksum_tmp15 <= checksum_adder(rcvd_data_length,rcvd_checksum) ;
		
		if (ip_rx_axis_tlast)
		begin				
			case(ip_rx_axis_tkeep)
			8'b00000001: 
				  begin		
					checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],8'd0}, checksum_tmp4);		  
				  end
			8'b00000011:
				  begin
					checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp4);		  
				  end
			8'b00000111: 
				 begin
					checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp4);		  
					checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[23:16],8'd0}, checksum_tmp5);
				  end
			8'b00001111: 
				  begin
					checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp4);		  
					checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp5);
				  end
			8'b00011111: 
				  begin
					checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp4);		  
					checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp5);
					checksum_tmp6  <= checksum_adder({ip_rx_axis_tdata[39:32],8'd0}, checksum_tmp6);		
				  end
			8'b00111111:
				  begin
					checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp4);		  
					checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp5);
					checksum_tmp6  <= checksum_adder({ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]}, checksum_tmp6);
				  end
			8'b01111111:
				  begin
					checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp4);		  
					checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp5);
					checksum_tmp6  <= checksum_adder({ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]}, checksum_tmp6);
					checksum_tmp7  <= checksum_adder({ip_rx_axis_tdata[55:48],8'd0}, checksum_tmp7);
				
				  end
			8'b11111111:
				  begin
					checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp4);		  
					checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp5);
					checksum_tmp6  <= checksum_adder({ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]}, checksum_tmp6);
					checksum_tmp7  <= checksum_adder({ip_rx_axis_tdata[55:48],ip_rx_axis_tdata[63:56]}, checksum_tmp7);				
					 end
			endcase	
		end
		else 
		begin
			checksum_tmp4   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp4);		  
			checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp5);
			checksum_tmp6  <= checksum_adder({ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]}, checksum_tmp6);
			checksum_tmp7  <= checksum_adder({ip_rx_axis_tdata[55:48],ip_rx_axis_tdata[63:56]}, checksum_tmp7);
		end
	end
  end
  
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin

		checksum_tmp8  <= 18'd0 ;
		checksum_tmp9  <= 18'd0 ;
		checksum_tmp10 <= 19'd0 ;
		checksum_tmp11 <= 32'd0 ;
		checksum_tmp12 <= 32'd0 ;
		checksum_tmp13 <= 32'd0 ;
		checksum_tmp14 <= 32'd0 ;
		checksum_tmp16 <= 20'd0 ;
	end
	else if (rcv_state == UDP_RCV_HEAD  && ip_rx_axis_tvalid)
	begin

		checksum_tmp8  <= 18'd0 ;
		checksum_tmp9  <= 18'd0 ;
		checksum_tmp10 <= 19'd0 ;
		checksum_tmp11 <= 32'd0 ;
		checksum_tmp12 <= 32'd0 ;
		checksum_tmp13 <= 32'd0 ;
		checksum_tmp14 <= 32'd0 ;
		checksum_tmp16 <= 20'd0 ;
	end
	else 
	begin
	
		checksum_tmp8  <= checksum_adder(checksum_tmp0, checksum_tmp1);
		checksum_tmp9  <= checksum_adder(checksum_tmp2, checksum_tmp3);	
		checksum_tmp10  <= checksum_adder(checksum_tmp9, checksum_tmp8);
		checksum_tmp16  <= checksum_adder(checksum_tmp15, checksum_tmp10);
		
		checksum_tmp11  <= checksum_adder(checksum_tmp4, checksum_tmp5);
		checksum_tmp12  <= checksum_adder(checksum_tmp6, checksum_tmp7);		
		checksum_tmp13  <= checksum_adder(checksum_tmp12, checksum_tmp11);	
		
		checksum_tmp14  <= checksum_adder(checksum_tmp16, checksum_tmp13);

	end
  end 
  
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
      checksum_buf <= 32'd0;
	  checksum_buf_dly <= 32'd0;
	end
    else
	begin
      checksum_buf <= checksum_out(checksum_tmp14) ;
	  checksum_buf_dly <= checksum_out(checksum_buf) ;
	end
  end
 
assign checksum = ~checksum_buf_dly[15:0] ; 


/**************************************************************
Checksum check
**************************************************************/
localparam DlyLength = 7 ;

reg [63:0]       	   	      			udp_tdata_dly [DlyLength-1:0];
reg [7:0]     	     	      			udp_tkeep_dly [DlyLength-1:0];
reg [DlyLength-1:0]                     udp_tvalid_dly ;	
reg [DlyLength-1:0]                     udp_tlast_dly;
reg [DlyLength-1:0]                     udp_tusr_dly;


 wire  [63:0]       	   	      udp_fifo_axis_tdata ;
 wire  [7:0]     	     	  udp_fifo_axis_tkeep ;
 wire                          udp_fifo_axis_tvalid ;		 
 wire                          udp_fifo_axis_tlast ;
 wire                          udp_fifo_axis_tusr ;

genvar i ;
generate	
	for(i = 0 ;i < DlyLength; i=i+1)
	begin : shifter
		always @(posedge rx_axis_aclk)
		begin
			if (~rx_axis_areset)
			begin
				udp_tdata_dly[i] 	<= 64'd0 ;
				udp_tkeep_dly[i] 	<= 8'd0 ;
				udp_tvalid_dly[i]   <= 1'b0 ;
				udp_tlast_dly[i]    <= 1'b0 ;	
				udp_tusr_dly[i]     <= 1'b0 ;					
			end
			else
			begin
				udp_tdata_dly[i] <= (i == 0)? udp_tdata : udp_tdata_dly[i-1] ;
				udp_tkeep_dly[i] <= (i == 0)? udp_tkeep : udp_tkeep_dly[i-1] ;
				udp_tvalid_dly[i] <= (i == 0)? udp_tvalid : udp_tvalid_dly[i-1] ;
				udp_tlast_dly[i] <= (i == 0)? udp_tlast : udp_tlast_dly[i-1] ;
				
				if (i == 0)
					udp_tusr_dly[i] <= udp_tusr ;
				else if (i == DlyLength-1)
				begin
					if (checksum == 16'd0)
						udp_tusr_dly[i] <= udp_tusr_dly[i-1] ;
					else
						udp_tusr_dly[i] <= 1'b0 ;
				end
				else
					udp_tusr_dly[i] <= udp_tusr_dly[i-1] ;
				
			end
		end
	end
endgenerate


assign udp_fifo_axis_tdata     =  udp_tdata_dly[DlyLength-1] ;
assign udp_fifo_axis_tkeep     =  udp_tkeep_dly[DlyLength-1] ; 
assign udp_fifo_axis_tvalid    =  udp_tvalid_dly[DlyLength-1] ;
assign udp_fifo_axis_tlast	 =  udp_tlast_dly[DlyLength-1] ;	 		
assign udp_fifo_axis_tusr		 =  udp_tusr_dly[DlyLength-1] ;	 


/**************************************************************
frame storage and send
**************************************************************/
wire						udp_fifo_rden ;
wire [73:0]				udp_fifo_rdata ; 
wire						udp_length_rden ;
wire [39:0]				udp_length_rdata ; 
wire						empty; 
reg						tusr ;
reg [15:0]					word_len ;
reg [15:0]					send_cnt ;
reg [15:0]					stream_word_cnt ;
reg [15:0]					stream_word_len ;

    reg [15:0]                    udp_len ;
  reg [15:0]                    udp_data_length ;
  reg [7:0]                    udp_keep ;
   
  /* Record data length from stream */
  always @(posedge rx_axis_aclk)
    begin
      if (~rx_axis_areset)
      begin
        stream_word_cnt <= 16'd0 ;
        stream_word_len <= 16'd0 ;
      end
      else if (udp_tvalid)
      begin
          if (udp_tlast)
          begin
              stream_word_cnt <= 16'd0 ;
              stream_word_len <= stream_word_cnt + 1'b1 ;
              udp_data_length <= rcvd_data_length ;
          end
          else
          begin
              stream_word_cnt <= stream_word_cnt + 1'b1 ;
          end
      end
    end
 /* fifo for axis data */ 
   std_fwft_fifo 
  #(
    .WIDTH(74) ,
    .DEPTH(11),
    .FIFO_TYPE("fwft")
  )
  udp_data_fifo
  (
    .clk       (rx_axis_aclk   ),
    .rst_n     (rx_axis_areset ),
    .wren      (udp_fifo_axis_tvalid),
    .rden      (udp_fifo_rden ),
    .data      ({udp_fifo_axis_tdata,udp_fifo_axis_tkeep,udp_fifo_axis_tlast,udp_fifo_axis_tusr}),
    .q         (udp_fifo_rdata),
    .full      (  ),
    .empty     (  )
  ) ;
 /* fifo for udp data length and stream word length */   
   std_fwft_fifo 
  #(
    .WIDTH(40) ,
    .DEPTH(11),
    .FIFO_TYPE("fwft")
  )
  udp_length_fifo
  (
    .clk       (rx_axis_aclk   ),
    .rst_n     (rx_axis_areset ),
    .wren      (udp_fifo_axis_tvalid & udp_fifo_axis_tlast),
    .rden      (udp_length_rden ),
    .data      ({udp_data_length,7'd0,udp_fifo_axis_tusr,stream_word_len}),
    .q         (udp_length_rdata),
    .full      (  ),
    .empty     (empty  )
  ) ;
 
 /* udp stream send statement */   
  localparam SEND_IDLE        = 2'b01 ;
  localparam SEND_DATA        = 2'b10 ;
  
  
  reg [1:0]    send_state  ;
  reg [1:0]    send_next_state ;
  
  
  
  always @(posedge rx_axis_aclk)
    begin
      if (~rx_axis_areset)
        send_state  <=  SEND_IDLE  ;
      else
        send_state  <= send_next_state ;
    end
    
  always @(*)
    begin
      case(send_state)
        SEND_IDLE            :
          begin
            if (~empty)
              send_next_state <= SEND_DATA ;
            else
              send_next_state <= SEND_IDLE ;
          end        
        SEND_DATA            :
          begin
            if (send_cnt == word_len-1)
              send_next_state <= SEND_IDLE ;
            else
              send_next_state <= SEND_DATA ;
          end    
        default :  send_next_state <= SEND_IDLE ;
      endcase
    end
  
  assign udp_fifo_rden = (send_state == SEND_DATA) ;		/* read out data */  
  assign udp_length_rden = (send_state == SEND_IDLE) & (send_state != send_next_state);		/* read out data length */  
  
  /* word length, tkeep calculation */   
  always @(posedge rx_axis_aclk)
    begin
      if (~rx_axis_areset)
      begin
        udp_len <= 16'd0 ;
        word_len <= 16'd0;
        tusr <= 1'b0 ;
        udp_keep <= 8'h00 ;
      end
      else if (send_state == SEND_IDLE && send_state != send_next_state)
      begin
        if (~(|udp_length_rdata[26:24]))		//if lower 3 bits equal to zero, it means full word
        begin
          udp_len  <= udp_length_rdata[39:27] - 1 ;  //valid udp word length is count except udp header
          udp_keep <= 8'hff ;
        end
        else 
        begin
          udp_len  <= udp_length_rdata[39:27] ;		//lower 3 bits not equal to zero
          case(udp_length_rdata[26:24])				//last word tkeep coder
              3'd1     : udp_keep <= 8'b0000_0001 ;
              3'd2     : udp_keep <= 8'b0000_0011 ;
              3'd3     : udp_keep <= 8'b0000_0111 ;
              3'd4     : udp_keep <= 8'b0000_1111 ;
              3'd5     : udp_keep <= 8'b0001_1111 ;
              3'd6     : udp_keep <= 8'b0011_1111 ;
              3'd7     : udp_keep <= 8'b0111_1111 ;
              default : udp_keep <= 8'b1111_1111 ;
          endcase
        end
        word_len <= udp_length_rdata[15:0];	//record word length
        tusr <= udp_length_rdata[16] ;		//record tusr
      end
    end
  
  always @(posedge rx_axis_aclk)
    begin
      if (~rx_axis_areset)
          send_cnt <= 16'd0;
      else if (send_state == SEND_DATA)
          send_cnt <= send_cnt + 1;
      else
          send_cnt <= 16'd0;
    end
  /* udp stream control */   
  always @(posedge rx_axis_aclk)
    begin
      if (~rx_axis_areset)
      begin
        udp_rx_axis_tdata <= 64'd0;
        udp_rx_axis_tkeep <= 8'd0 ;
        udp_rx_axis_tvalid <= 1'b0 ;
        udp_rx_axis_tlast <= 1'b0 ;
        udp_rx_axis_tusr <= 1'b0 ;
      end
      else if (send_state == SEND_DATA && tusr)
      begin
          if (send_cnt < udp_len)
          begin
              udp_rx_axis_tdata     <= udp_fifo_rdata[73:10];            
              udp_rx_axis_tvalid  <= 1'b1 ; 
              
              if (send_cnt == udp_len - 1)			//When last word, tkeep equals to udp_keep signal
              begin
                  udp_rx_axis_tkeep     <= udp_keep ;
                  udp_rx_axis_tlast     <= 1'b1  ;
                  udp_rx_axis_tusr    <= 1'b1   ;
              end
              else
              begin
                  udp_rx_axis_tkeep     <= udp_fifo_rdata[9:2] ;
                  udp_rx_axis_tlast     <= udp_fifo_rdata[1];
                  udp_rx_axis_tusr    <= udp_fifo_rdata[0];
              end
          end
          else
          begin
              udp_rx_axis_tdata <= 64'd0;
              udp_rx_axis_tkeep <= 8'd0 ;
              udp_rx_axis_tvalid <= 1'b0 ;
              udp_rx_axis_tlast <= 1'b0 ;
              udp_rx_axis_tusr <= 1'b0 ;
          end
      end
      else
      begin
        udp_rx_axis_tdata <= 64'd0;
        udp_rx_axis_tkeep <= 8'd0 ;
        udp_rx_axis_tvalid <= 1'b0 ;
        udp_rx_axis_tlast <= 1'b0 ;
        udp_rx_axis_tusr <= 1'b0 ;
      end
    end    

	
endmodule



// IP Decryptor end

