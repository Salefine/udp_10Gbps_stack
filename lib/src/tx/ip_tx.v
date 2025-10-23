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
//   Description:  ip transmit module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//  2020/12/27    myj          1.1         use pkg_fifo_almost_full to control package data;
//										   package identify_code with checksum;
//										   support jumbo frame
//********************************************************************************/
module ip_tx
       (        
         input  [7:0]         			ip_send_type,			//send type : udp or icmp
         input  [31:0]        			src_ip_addr,			//source ip address
         input  [31:0]        			dst_ip_addr,			//destination ip address
			
					
		 input                			tx_axis_aclk,
         input                			tx_axis_areset,  
		/* ip tx axis interface */			
		 input  [63:0]        			ip_tx_axis_tdata,
         input  [7:0]     	  			ip_tx_axis_tkeep,
         input                			ip_tx_axis_tvalid,		 
         input                			ip_tx_axis_tlast,
         output 	           				ip_tx_axis_tready,
		/* tx axis interface to frame */			
		 output reg [63:0]    			frame_tx_axis_tdata,
		 output reg [7:0]     			frame_tx_axis_tkeep,
		 output reg           			frame_tx_axis_tvalid,	
		 output reg           			frame_tx_axis_tlast,
         input                			frame_tx_axis_tready,
		 
		 output						 	ip_not_empty,	//ip layer is ready to send data
		 output 						rcv_stream_end			//receive stream end signal
       ) ;
       
localparam ip_version    = 4'h4     ;  //ipv4
localparam header_len    = 4'h5     ;  //header length Fixed 5
localparam TTL    		 = 8'hff     ;  //ttl


/**************************************************************
*First : storage stream data and record byte length or something
**************************************************************/
	
reg						stream_byte_rden ; 	
wire [31:0]				stream_byte_rdata 	  ;
wire					stream_byte_fifo_empty ;

wire					stream_data_rden ;
wire [73:0]           	stream_data_rdata ;


reg [15:0]				identify_code ;





/* Receiver stream data from udp or icmp */
stream_to_fifo 
	#(
		.TransType("IP")
	)
	ip_stream_inst
	(
	.tx_type				   ({8'h00,ip_send_type}    ),		
	.tx_axis_aclk              (tx_axis_aclk            ),
    .tx_axis_areset   		   (tx_axis_areset   		),			
	.tx_axis_tdata             (ip_tx_axis_tdata        ),
    .tx_axis_tkeep             (ip_tx_axis_tkeep        ),
    .tx_axis_tvalid 		   (ip_tx_axis_tvalid 		), 
    .tx_axis_tlast             (ip_tx_axis_tlast        ),
    .tx_axis_tready 		   (ip_tx_axis_tready 		), 
	.stream_byte_fifo_empty    (stream_byte_fifo_empty  ),		
	.stream_byte_rden	       (stream_byte_rden	    ),
	.stream_byte_rdata 	       (stream_byte_rdata 	    ),	 
	.stream_data_rden          (stream_data_rden        ),
	.stream_data_rdata  	   (stream_data_rdata  	    ),	 
	.rcv_stream_end            (rcv_stream_end          )
    );



/**************************************************************
*Second : After one frame received, then generate ip head checksum
**************************************************************/
reg [5:0]				checksum_cnt ;
reg 					checksum_finish ;

wire					ip_head_fifo_full ;
wire					ip_head_fifo_almost_full ;
wire					ip_head_fifo_empty ;
reg						ip_head_wren ;
reg						ip_head_rden ;
reg  [55:0]           	ip_head_wdata ;
wire [55:0]           	ip_head_rdata ;

reg [7:0]				ip_type ;

reg [15:0]				ip_send_data_length ;


/* Receiver stream data from udp or icmp FSM */
parameter CK_IDLE         = 4'b0001 ;
parameter CK_GEN_WAIT     = 4'b0010 ;
parameter CK_GEN   		  = 4'b0100 ;
parameter CK_GEN_END   	  = 4'b1000 ;


reg [3:0]    ck_state  ;
reg [3:0]    ck_next_state ;

always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      ck_state  <=  CK_IDLE  ;
    else
      ck_state  <= ck_next_state ;
  end
  
always @(*)
  begin
    case(ck_state)  
	  CK_IDLE     :
        begin
          if (~stream_byte_fifo_empty)
            ck_next_state <= CK_GEN_WAIT ;
          else
            ck_next_state <= CK_IDLE ;
        end 
      CK_GEN_WAIT     :
            ck_next_state <= CK_GEN ;
	  CK_GEN:
		begin
          if (checksum_finish)
            ck_next_state <= CK_GEN_END ;
          else
            ck_next_state <= CK_GEN ;
        end  
      CK_GEN_END        :
	  begin
		if (~ip_head_fifo_almost_full)
			ck_next_state <= CK_IDLE ;
		else
			ck_next_state <= CK_GEN_END ;
	  end
      default          :
        ck_next_state <= CK_IDLE ;
    endcase
  end

//read out stream byte counter
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
		stream_byte_rden <= 1'b0 ;
    else if (ck_state == CK_IDLE && ck_state != ck_next_state)
		stream_byte_rden <= 1'b1 ;
	else
		stream_byte_rden <= 1'b0 ;
  end  


always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
	begin
      ip_send_data_length <= 16'd0 ;
	  ip_type <= 8'd0 ;
	end
    else if (ck_state == CK_GEN_WAIT && ck_state != ck_next_state)
	begin
      ip_send_data_length <= stream_byte_rdata[15:0] + 20 ;
	  ip_type <= stream_byte_rdata[23:16] ;
	end
  end  


  
  
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      checksum_cnt  <= 6'd0 ;
    else if (ck_state == CK_GEN)
      checksum_cnt <= checksum_cnt + 1'b1 ;
    else
      checksum_cnt <= 6'd0 ;
  end



//checksum generation

reg  [16:0] checksum_tmp0 ;
reg  [16:0] checksum_tmp1 ;
reg  [16:0] checksum_tmp2 ;
reg  [16:0] checksum_tmp3 ;
reg  [16:0] checksum_tmp4 ;
reg  [17:0] checksum_tmp5 ;
reg  [17:0] checksum_tmp6 ;
reg  [18:0] checksum_tmp7 ;
reg  [19:0] checksum_tmp8 ;
reg  [19:0] check_out ;
reg  [19:0] checkout_buf ;
reg  [15:0] checksum ;


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
    input       [31:0]  dataina
  );
  
  begin
    checksum_out = dataina[15:0]+dataina[31:16];
  end
  
endfunction


always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      begin
        checksum_tmp0 <= 17'd0 ;
        checksum_tmp1 <= 17'd0 ;
        checksum_tmp2 <= 17'd0 ;
        checksum_tmp3 <= 17'd0 ;
        checksum_tmp4 <= 17'd0 ;
        checksum_tmp5 <= 18'd0 ;
        checksum_tmp6 <= 18'd0 ;
        checksum_tmp7 <= 19'd0 ;
        checksum_tmp8 <= 20'd0 ;
        check_out     <= 20'd0 ;
        checkout_buf  <= 20'd0 ;
      end
    else if (ck_state == CK_GEN)
      begin
        checksum_tmp0 <= checksum_adder(16'h4500,ip_send_data_length);
        checksum_tmp1 <= checksum_adder(identify_code, 16'h4000) ;
        checksum_tmp2 <= checksum_adder({TTL,ip_type}, 16'h0000) ;
        checksum_tmp3 <= checksum_adder(src_ip_addr[31:16], src_ip_addr[15:0]) ;
        checksum_tmp4 <= checksum_adder(dst_ip_addr[31:16], dst_ip_addr[15:0]) ;
        checksum_tmp5 <= checksum_adder(checksum_tmp0, checksum_tmp1) ;
        checksum_tmp6 <= checksum_adder(checksum_tmp2, checksum_tmp3) ;
        checksum_tmp7 <= checksum_adder(checksum_tmp5, checksum_tmp6) ;
        checksum_tmp8 <= checksum_adder(checksum_tmp4, checksum_tmp7) ;
        check_out     <= checksum_out(checksum_tmp8) ;
        checkout_buf  <= checksum_out(check_out) ;
      end
    else if (ck_state == CK_IDLE)
      begin
        checksum_tmp0 <= 17'd0 ;
        checksum_tmp1 <= 17'd0 ;
        checksum_tmp2 <= 17'd0 ;
        checksum_tmp3 <= 17'd0 ;
        checksum_tmp4 <= 17'd0 ;
        checksum_tmp5 <= 18'd0 ;
        checksum_tmp6 <= 18'd0 ;
        checksum_tmp7 <= 19'd0 ;
        checksum_tmp8 <= 20'd0 ;
        check_out     <= 20'd0 ;
        checkout_buf  <= 20'd0 ;
      end
  end
   
  
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      checksum <= 16'd0 ;
    else if (ck_state == CK_GEN)
      checksum <= ~checkout_buf[15:0] ;
  end


always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      checksum_finish <= 1'b0 ;
    else if (ck_state == CK_GEN && checksum_cnt == 6'd8)
      checksum_finish <= 1'b1 ;
    else
      checksum_finish <= 1'b0 ;
  end


always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
	begin
		ip_head_wdata <= 56'd0 ;
		ip_head_wren <= 1'b0 ;
		identify_code  <= 16'd0 ;
	end
    else if (ck_state == CK_GEN_END && ~ip_head_fifo_almost_full)
	begin
        ip_head_wdata <= {identify_code, ip_send_data_length, checksum, ip_type} ;
		ip_head_wren <= 1'b1 ;
		identify_code  <= identify_code + 1'b1 ;
	end
	else
	begin
        ip_head_wdata <= 56'd0 ;
		ip_head_wren <= 1'b0 ;
	end
  end
 

/* sync fifo for ip head data */
 std_fwft_fifo 
#(
  .WIDTH(56) ,
  .DEPTH(5),
  .FIFO_TYPE("fwft")
)
ip_head_fifo
(
  .clk       (tx_axis_aclk   ),
  .rst_n     (tx_axis_areset ),
  .wren      (ip_head_wren			),
  .rden      (ip_head_rden  		),
  .data      (ip_head_wdata			),
  .q         (ip_head_rdata    		),
  .full      (ip_head_fifo_full  	),
  .empty     (ip_head_fifo_empty ),
  .almost_full	(ip_head_fifo_almost_full)
) ;  


/***************************************************************************************
*Third : After checksum generated, then package data with ip head and store into fifo
***************************************************************************************/
reg 					pkg_wren  		;   //package fifo write enable
wire					pkg_rden  		;   //package fifo read enable
reg [73:0]				pkg_wdata 		;   //package fifo write data
wire [73:0]				pkg_rdata 		;   //package fifo read data
wire					pkg_fifo_full 	;   //package fifo full
wire					pkg_fifo_empty 		 ;    //package fifo empty
wire					pkg_fifo_almost_full ;    //package fifo almost full, there is only one data can be wirte into fifo


reg [15:0]				ip_data_len ;	//ip data length
reg [15:0]				ip_checksum ;	//ip header checksum
reg [7:0]				frame_type 	;	//type : udp or icmp
reg [15:0]				ip_identify_code 	;	//ip identify code along with ip checksum
/* axis interface */
wire [63:0]				stream_data ; 
wire [7:0]				stream_keep ;
wire 					stream_valid;
wire 					stream_last ;
/* register for data and keep */
reg [63:0]				stream_data_dly ;
reg [7:0]				stream_keep_dly ;

wire					pkg_len_fifo_empty ;	//package length fifo empty signal

/* package stream data into fifo, after add ip header */    
localparam PKG_IDLE         = 8'b0000_0001 ;
localparam PKG_WAIT         = 8'b0000_0010 ;
localparam PKG_HEAD_1ST     = 8'b0000_0100 ;
localparam PKG_HEAD_2ND     = 8'b0000_1000 ;
localparam PKG_HEAD_3RD     = 8'b0001_0000 ;
localparam PKG_DATA         = 8'b0010_0000 ;
localparam PKG_LAST_ONE     = 8'b0100_0000 ;
localparam PKG_END	        = 8'b1000_0000 ;



reg [7:0]    pkg_state  ;
reg [7:0]    pkg_next_state ;


always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      pkg_state  <=  PKG_IDLE  ;
    else
      pkg_state  <= pkg_next_state ;
  end
  
always @(*)
  begin
    case(pkg_state)
      PKG_IDLE            :
        begin
          if (~ip_head_fifo_empty)
            pkg_next_state <= PKG_WAIT ;
          else
            pkg_next_state <= PKG_IDLE ;
        end		

	  PKG_WAIT   :
		    pkg_next_state <= PKG_HEAD_1ST ;
	
	  PKG_HEAD_1ST      :
        begin
          if (~pkg_fifo_almost_full)
            pkg_next_state <= PKG_HEAD_2ND ;
          else
            pkg_next_state <= PKG_HEAD_1ST ; 	
        end
	  PKG_HEAD_2ND      :
        begin
          if (~pkg_fifo_almost_full)
            pkg_next_state <= PKG_HEAD_3RD ;
          else
            pkg_next_state <= PKG_HEAD_2ND ; 	
        end
	  PKG_HEAD_3RD      :
        begin
		  if (~pkg_fifo_almost_full)
            pkg_next_state <= PKG_DATA ;
          else
            pkg_next_state <= PKG_HEAD_3RD ; 	
        end
			
      PKG_DATA       :
		  begin			
			if (~pkg_fifo_almost_full & stream_valid & stream_last & (|stream_keep[7:4]))   /* if last keep bigger than 4 data counter, switch to PKG_LAST_ONE state */
				pkg_next_state <= PKG_LAST_ONE ;			
			else if (~pkg_fifo_almost_full & stream_valid & stream_last & ~(|stream_keep[7:4]))  /* if last keep less than 4 data counter, switch to PKG_END state */
				pkg_next_state <= PKG_END ;
			else
				pkg_next_state <= PKG_DATA ; 	
		  end
	  PKG_LAST_ONE    :
		  begin
			if (~pkg_fifo_almost_full)
				pkg_next_state <= PKG_END ;	
			else
				pkg_next_state <= PKG_LAST_ONE ;
		  end
	  PKG_END    :	pkg_next_state <= PKG_IDLE ;
      default        :
        pkg_next_state <= PKG_IDLE ;
    endcase
  end  
// /* every package state round, identify code plus 1  */
// always @(posedge tx_axis_aclk)
  // begin
    // if (~tx_axis_areset)
      // identify_code  <= 16'd0 ;
    // else if (pkg_state == PKG_END && pkg_state != pkg_next_state)
      // identify_code  <= identify_code + 1'b1 ;
  // end

/* read word data  */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      ip_head_rden <= 1'b0 ;
    else if (pkg_state == PKG_IDLE && pkg_state != pkg_next_state)
      ip_head_rden <= 1'b1 ;
    else
      ip_head_rden <= 1'b0 ;
  end
 
/* register for type and word length  */    
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
	begin
	  frame_type <= 16'd0 ;
	  ip_data_len <= 16'd0 ;
	  ip_checksum <= 16'd0 ;
	  ip_identify_code <= 16'd0 ;
	end
    else if (pkg_state == PKG_WAIT)
	begin
	  frame_type <= ip_head_rdata[7:0] ;	  
	  ip_checksum <= ip_head_rdata[23:8] ;
	  ip_data_len <= ip_head_rdata[39:24]  ;
	  ip_identify_code <= ip_head_rdata[55:40]  ;
	end
  end
/* When package fifo is not full and state is PKG_HEAD_3RD or PKG_DATA, read out stream data */ 
assign stream_data_rden = (pkg_state == PKG_HEAD_3RD || pkg_state == PKG_DATA) & (~pkg_fifo_almost_full) ;
 
/* Write packaged data into fifo */  
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      pkg_wren <= 1'b0 ;
    else if (~pkg_fifo_almost_full)
	begin
		if (pkg_state == PKG_HEAD_1ST || pkg_state == PKG_HEAD_2ND || pkg_state == PKG_HEAD_3RD || pkg_state == PKG_DATA || pkg_state == PKG_LAST_ONE)
			pkg_wren <= 1'b1 ;
		else 
			pkg_wren <= 1'b0 ;
	end
    else
		pkg_wren <= 1'b0 ;

  end  



assign stream_data  = stream_data_rdata[73:10];
assign stream_keep  = stream_data_rdata[9:2] ;
assign stream_valid = stream_data_rdata[1] ;
assign stream_last  = stream_data_rdata[0] ;


always @(posedge tx_axis_aclk)
begin
  if (~tx_axis_areset)
	stream_data_dly <= 64'd0 ;
  else if (~pkg_fifo_almost_full)
	stream_data_dly <= stream_data ;
end

always @(posedge tx_axis_aclk)
begin
  if (~tx_axis_areset)
	stream_keep_dly <= 8'd0 ;
  else if (~pkg_fifo_almost_full)
	stream_keep_dly <= stream_keep ;	
end

/* sync fifo for package data */
 std_fwft_fifo 
#(
  .WIDTH(74) ,
  .DEPTH(11),
  .FIFO_TYPE("fwft")
)
pkg_fifo
(
  .clk       (tx_axis_aclk   ),
  .rst_n     (tx_axis_areset ),
  .wren      (pkg_wren			),
  .rden      (pkg_rden  		),
  .data      (pkg_wdata),
  .q         (pkg_rdata    		),
  .full      (pkg_fifo_full  	),
  .empty     (pkg_fifo_empty ),
  .almost_full	(pkg_fifo_almost_full) 
) ;  


assign ip_not_empty = ~pkg_fifo_empty ;
  
   // Form pkg_wdata here
   // opreg7to0

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[7:0]    <= 8'hff;
         PKG_HEAD_2ND 		: pkg_wdata[7:0]    <= 8'hff;
         PKG_HEAD_3RD 		: pkg_wdata[7:0]    <= 8'hff;
         PKG_DATA      		: begin
								if (stream_valid & stream_last)
								begin
									if (~(|stream_keep[7:4]))										
										pkg_wdata[7:0]    <= stream_keep<<4 | 8'hf;
									else
										pkg_wdata[7:0]    <= 8'hff;
								end
								else
									pkg_wdata[7:0]    <= 8'hff;
							  end
         PKG_LAST_ONE      	: begin
								pkg_wdata[7:0]    <= stream_keep_dly>>4;
							  end
         PKG_IDLE      		: pkg_wdata[7:0]    <= 8'h00;
         default   			: pkg_wdata[7:0]    <= 8'h00;
      endcase
   end

   // opreg15to8

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST  		: pkg_wdata[15:8]   <= {ip_version, header_len};
         PKG_HEAD_2ND 		: pkg_wdata[15:8]   <= TTL;
         PKG_HEAD_3RD 		: pkg_wdata[15:8]   <= dst_ip_addr[31:24];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[15:8]   <= stream_data_dly[39:32];
		 PKG_LAST_ONE		: if (~pkg_fifo_almost_full) pkg_wdata[15:8]   <= stream_data_dly[39:32];
         PKG_IDLE     		: pkg_wdata[15:8]   <= 8'h00;
         default   			: pkg_wdata[15:8]   <= 8'h00;
      endcase
   end

   // opreg23to16

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[23:16]  <= 8'h00;
         PKG_HEAD_2ND 		: pkg_wdata[23:16]  <= frame_type;
         PKG_HEAD_3RD 		: pkg_wdata[23:16]  <= dst_ip_addr[23:16];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[23:16]  <= stream_data_dly[47:40];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[23:16]  <= stream_data_dly[47:40];
         PKG_IDLE      		: pkg_wdata[23:16]  <= 8'h00;
         default   			: pkg_wdata[23:16]  <= 8'h00;
      endcase
   end

   // opreg31to24

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[31:24]  <= ip_data_len[15:8];
         PKG_HEAD_2ND 		: pkg_wdata[31:24]  <= ip_checksum[15:8];
         PKG_HEAD_3RD 		: pkg_wdata[31:24]  <= dst_ip_addr[15:8];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[31:24]  <= stream_data_dly[55:48];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[31:24]  <= stream_data_dly[55:48];
         PKG_IDLE      		: pkg_wdata[31:24]  <= 8'h00;
         default  			: pkg_wdata[31:24]  <= 8'h00;
      endcase
   end

   // opreg39to32

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[39:32]  <= ip_data_len[7:0];
         PKG_HEAD_2ND 		: pkg_wdata[39:32]  <= ip_checksum[7:0];
         PKG_HEAD_3RD 		: pkg_wdata[39:32]  <= dst_ip_addr[7:0];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[39:32]  <= stream_data_dly[63:56];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[39:32]  <= stream_data_dly[63:56];
         PKG_IDLE      		: pkg_wdata[39:32]  <= 8'h00;
         default   			: pkg_wdata[39:32]  <= 8'h00;
      endcase
   end

   // opreg47to40

always @(posedge tx_axis_aclk)
   begin
       case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[47:40]  <= ip_identify_code[15:8];
         PKG_HEAD_2ND 		: pkg_wdata[47:40]  <= src_ip_addr[31:24];
         PKG_HEAD_3RD 		: if (~pkg_fifo_almost_full) pkg_wdata[47:40]  <= stream_data[7:0];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[47:40]  <= stream_data[7:0];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[47:40]  <= stream_data[7:0];
         PKG_IDLE      		: pkg_wdata[47:40]  <= 8'h00;
         default   			: pkg_wdata[47:40]  <= 8'h00;
      endcase
   end

   // opreg55to48

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[55:48]  <= ip_identify_code[7:0];
         PKG_HEAD_2ND 		: pkg_wdata[55:48]  <= src_ip_addr[23:16];
         PKG_HEAD_3RD 		: if (~pkg_fifo_almost_full) pkg_wdata[55:48]  <= stream_data[15:8];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[55:48]  <= stream_data[15:8];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[55:48]  <= stream_data[15:8];
         PKG_IDLE      		: pkg_wdata[55:48]  <= 8'h00;
         default   			: pkg_wdata[55:48]  <= 8'h00;
      endcase
   end

   // opreg63to56

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[63:56]  <= 8'h40;
         PKG_HEAD_2ND 		: pkg_wdata[63:56]  <= src_ip_addr[15:8];
         PKG_HEAD_3RD 		: if (~pkg_fifo_almost_full) pkg_wdata[63:56]  <= stream_data[23:16];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[63:56]  <= stream_data[23:16];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[63:56]  <= stream_data[23:16];
         PKG_IDLE      		: pkg_wdata[63:56]  <= 8'h00;
         default   			: pkg_wdata[63:56]  <= 8'h00;
      endcase
   end	
   // opreg71to64
always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[71:64]  <= 8'h00;
         PKG_HEAD_2ND 		: pkg_wdata[71:64]  <= src_ip_addr[7:0];
         PKG_HEAD_3RD 		: if (~pkg_fifo_almost_full) pkg_wdata[71:64]  <= stream_data[31:24];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[71:64]  <= stream_data[31:24];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[71:64]  <= stream_data[31:24];
         PKG_IDLE      		: pkg_wdata[71:64]  <= 8'h00;
         default   			: pkg_wdata[71:64]  <= 8'h00;
      endcase
   end	

   // opreg73to72	bit73 equals to tvalid; bit72 equals to tlast
always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_HEAD_1ST   	: pkg_wdata[73:72]    <= 2'b10;
         PKG_HEAD_2ND 		: pkg_wdata[73:72]    <= 2'b10;
         PKG_HEAD_3RD 		: pkg_wdata[73:72]    <= 2'b10;
         PKG_DATA      		: begin
								if (stream_valid & stream_last)
								begin
									if (~(|stream_keep[7:4]))										
										pkg_wdata[73:72]    <= 2'b11;
									else
										pkg_wdata[73:72]    <= 2'b10;
								end
								else
									pkg_wdata[73:72]    <= 2'b10;
							  end
         PKG_LAST_ONE      	: pkg_wdata[73:72]    <= 2'b11;
         PKG_IDLE      		: pkg_wdata[73:72]    <= 2'b00;
         default   			: pkg_wdata[73:72]    <= 2'b00;
      endcase
   end


/**********************************************************************************
*Fourth : When there package fifo is not empty, then read out frame
***********************************************************************************/
  
localparam FRAME_IDLE              = 2'b01 ;
localparam FRAME_SEND_DATA         = 2'b10 ;



reg [1:0]    frame_state  ;
reg [1:0]    frame_next_state ;


always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      frame_state  <=  FRAME_IDLE  ;
    else
      frame_state  <= frame_next_state ;
  end
  
always @(*)
  begin
    case(frame_state)
      FRAME_IDLE            :
         begin
          if (ip_not_empty ) 
            frame_next_state <= FRAME_SEND_DATA ;
           else
            frame_next_state <= FRAME_IDLE ;
        end		 
      FRAME_SEND_DATA       :
        begin
          if (frame_tx_axis_tready & frame_tx_axis_tvalid & frame_tx_axis_tlast)
            frame_next_state <= FRAME_IDLE ;
          else
            frame_next_state <= FRAME_SEND_DATA ; 	
        end
      default        :
        frame_next_state <= FRAME_IDLE ;
    endcase
  end  



assign pkg_rden = (frame_state == FRAME_SEND_DATA) & frame_tx_axis_tready & ip_not_empty ;



always @(*)
  begin
	if (frame_state == FRAME_SEND_DATA)
	begin
		frame_tx_axis_tdata <= pkg_rdata[71:8];
		frame_tx_axis_tkeep <= pkg_rdata[7:0] ;
		frame_tx_axis_tvalid <= pkg_rdata[73] ;
		frame_tx_axis_tlast <= pkg_rdata[72] ;
	end
	else
	begin
      frame_tx_axis_tdata <= 64'd0;
	  frame_tx_axis_tkeep <= 8'd0 ;
	  frame_tx_axis_tvalid <= 1'b0 ;
	  frame_tx_axis_tlast  <= 1'b0 ;
	end
  end
  
endmodule



// IP Decryptor end

