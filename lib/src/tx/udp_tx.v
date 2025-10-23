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
//   Description:  udp transmit module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//  2020/12/16    myj          1.0         support jumbo frame
//********************************************************************************/
module udp_tx
       (                                         
          input      [31:0]                src_ip_addr,     //source ip address
          input      [31:0]                dst_ip_addr,     //destination ip address
                                           
          input      [15:0]                udp_src_port,    //udp source port
          input      [15:0]                udp_dst_port,    //udp destination port
          
		  input                            tx_axis_aclk,
          input                            tx_axis_areset, 
		/* udp tx axis interface */		  
          input  [63:0]       			   udp_tx_axis_tdata,
          input  [7:0]     				   udp_tx_axis_tkeep,
          input                            udp_tx_axis_tvalid,		 
          input                            udp_tx_axis_tlast,
          output                           udp_tx_axis_tready,
		/* tx axis interface to ip */
		  output reg [63:0]       		   ip_tx_axis_tdata,
          output reg [7:0]     			   ip_tx_axis_tkeep,
          output reg                       ip_tx_axis_tvalid,		 
          output reg                       ip_tx_axis_tlast,
          input                            ip_tx_axis_tready,

		  input							   mac_exist,		//mac is exsit in arp cache
          output 	                       udp_not_empty			//udp layer is ready to send data

         
       ) ;

reg [15:0]				   		  udp_data_byte 		;  	//how many byte in udp data frame
wire [79:0]                       length_rd_data 		;	//length fifo read data
reg                               length_fifo_rden	 	;	//length fifo read enable signal
reg [15:0]                         udp_stream_cnt 		;  	//stream counter for 64bits data
wire 		                      udp_fifo_rden 		;	//udp fifo read enable signal
reg [15:0]                        udp_checksum 			;	//udp checksum
wire [15:0]                       stream_byte_len 		;	//udp stream byte length

reg 							  udp_tx_axis_tlast_d0 	;	//tlast latch 1
reg 							  udp_tx_axis_tlast_d1 	;	//tlast latch 2
                                  
wire   		                      length_fifo_full 		;	//length fifo full
wire							  length_fifo_empty 		;	//length fifo empty
wire							  length_fifo_almost_full 	;	//length fifo almost full, there is only one data can be wirte into fifo
wire 		                      udp_fifo_full 	;	//udp data fifo full
wire							  udp_fifo_empty 	;	//udp data fifo empty
wire							  udp_fifo_almost_full ;	//udp data fifo almost full, there is only one data can be wirte into fifo
wire [73:0]                       udp_fifo_rdata ;	//udp data fifo read data
/* checksum signals declaration  */ 

reg  [31:0]                       checksum_tmp0   ;
reg  [31:0]                       checksum_tmp1   ;
reg  [31:0]                       checksum_tmp2   ;
reg  [31:0]                       checksum_tmp3   ;

reg  [16:0]                       checksum_tmp4   ;
reg  [16:0]                       checksum_tmp5   ;
reg  [16:0]                       checksum_tmp6   ;
reg  [16:0]                       checksum_tmp7   ;
reg  [16:0]                       checksum_tmp8   ;                                                  
reg  [31:0]                       checksum_tmp9   ;
reg  [31:0]                       checksum_tmp10  ;
reg  [31:0]                       checksum_tmp11  ;
reg  [31:0]                       checksum_tmp12  ;
reg  [31:0]                       checksum_tmp13  ;
reg  [31:0]                       checksum_tmp14  ;

wire [15:0]						  checksum ;

reg  [31:0]						  checksum_d0 ;
reg  [31:0]						  checksum_d1 ;

                                  
reg  [63:0]						  checksum_udp_data   ;
                                
reg  [31:0]                       checksum_buf    ;
reg  [31:0]                       checksum_buf_dly    ;
reg  [5:0]                       checksum_cnt    ;
                                                  
reg                               checksum_wr     ;
reg                               checksum_rd     ;
reg  [31:0]                       checksum_in     ;
reg  [15:0]                       checksum_udp_len ;
wire [31:0]                       checksum_q       ;
wire 							  checksum_fifo_full ;
wire							  checksum_fifo_empty ;
wire							  checksum_fifo_almost_full ;

	   
/*****************************************************************************************
* First : udp stream data and counter store
*****************************************************************************************/
	   
/* when fifo not full, assert tready  */ 
assign udp_tx_axis_tready = mac_exist & ~(length_fifo_almost_full | udp_fifo_almost_full)  ;


stream_counter stream_inst
      (       
		.axis_aclk          (tx_axis_aclk),
        .axis_areset     	(tx_axis_areset), 			
		.axis_tdata         (udp_tx_axis_tdata),
        .axis_tkeep         (udp_tx_axis_tkeep),
        .axis_tvalid 	    (udp_tx_axis_tvalid),
        .axis_tlast         (udp_tx_axis_tlast),
        .axis_tready 	  	(udp_tx_axis_tready), 		
		.stream_byte_len    (stream_byte_len),
		.stream_word_len    ()
      ) ;


/* Two-stage register for tlast  */
always @(posedge tx_axis_aclk)
begin
    if (~tx_axis_areset)
	begin
		udp_tx_axis_tlast_d0 <= 1'b0 ;
		udp_tx_axis_tlast_d1 <= 1'b0 ;
	end
	else
	begin
		udp_tx_axis_tlast_d0 <= udp_tx_axis_tlast ;
		udp_tx_axis_tlast_d1 <= udp_tx_axis_tlast_d0 ;
	end
end
	

/* sync fifo for udp data length  */
std_fwft_fifo 
#(
  .WIDTH(80) ,
  .DEPTH(5),
  .FIFO_TYPE("fwft")
)
udp_length_fifo
(
  .clk       (tx_axis_aclk   ),
  .rst_n     (tx_axis_areset ),
  .wren      (~udp_tx_axis_tlast_d0 & udp_tx_axis_tlast_d1  ),
  .rden      (length_fifo_rden  ),
  .data      ({checksum_d0, checksum_d1,stream_byte_len}  ),
  .q         (length_rd_data     ),
  .full      (length_fifo_full),
  .empty     (length_fifo_empty 	),
  .almost_full	(length_fifo_almost_full)
) ;
/* sync fifo for udp data */
 std_fwft_fifo 
#(
  .WIDTH(74) ,
  .DEPTH(11),
  .FIFO_TYPE("fwft")
)
udp_data_fifo
(
  .clk       (tx_axis_aclk   ),
  .rst_n     (tx_axis_areset ),
  .wren      (udp_tx_axis_tvalid & udp_tx_axis_tready),
  .rden      (udp_fifo_rden  ),
  .data      ({udp_tx_axis_tdata, udp_tx_axis_tkeep,udp_tx_axis_tvalid,udp_tx_axis_tlast}),
  .q         (udp_fifo_rdata    ),
  .full      (udp_fifo_full  ),
  .empty     (udp_fifo_empty ),
  .almost_full	(udp_fifo_almost_full)
) ;



/*****************************************************************************************
*Second : generate udp checksum
*****************************************************************************************/
localparam CK_IDLE           = 4'b00001 ;
localparam UDP_LENGTH_READY  = 4'b00010 ;
localparam GEN_CHECKSUM      = 4'b00100 ;
localparam GEN_CHECKSUM_END  = 4'b01000 ;


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
      CK_IDLE            :
        begin
          if (~length_fifo_empty & ~checksum_fifo_almost_full)  //if there is data in fifo start generate checksum
            ck_next_state <= UDP_LENGTH_READY ;
          else
            ck_next_state <= CK_IDLE ;
        end	
	  UDP_LENGTH_READY:
            ck_next_state <= GEN_CHECKSUM ;
      GEN_CHECKSUM    :
        begin
          if (checksum_cnt == 6'd7)
            ck_next_state <= GEN_CHECKSUM_END ;
          else
            ck_next_state <= GEN_CHECKSUM ;
        end
      GEN_CHECKSUM_END :
        begin
          if (~checksum_fifo_almost_full)
            ck_next_state <= CK_IDLE ;
          else
            ck_next_state <= GEN_CHECKSUM_END ;
        end 
      default        :
        ck_next_state <= CK_IDLE ;
    endcase
  end






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
    if(~tx_axis_areset)
      begin
        checksum_tmp4 	<= 17'd0 ;
        checksum_tmp5 	<= 17'd0 ;
        checksum_tmp6 	<= 17'd0 ;
        checksum_tmp7 	<= 17'd0 ;
        checksum_tmp8 	<= 17'd0 ;
        checksum_tmp9 	<= 32'd0 ;
        checksum_tmp10	<= 32'd0 ;
        checksum_tmp11	<= 32'd0 ;
        checksum_tmp12	<= 32'd0 ;
		checksum_tmp13	<= 32'd0 ;
        checksum_tmp14	<= 32'd0 ;

      end
    else if (ck_state == GEN_CHECKSUM)
      begin
        checksum_tmp4  <= checksum_adder(src_ip_addr[31:16],src_ip_addr[15:0]); 
        checksum_tmp5  <= checksum_adder(dst_ip_addr[31:16],dst_ip_addr[15:0]); 
        checksum_tmp6  <= checksum_adder({8'd0,8'd17},checksum_udp_len);        
        checksum_tmp7  <= checksum_adder(udp_src_port,udp_dst_port);            
        checksum_tmp8  <= checksum_adder(checksum_udp_len, 16'd0);
        checksum_tmp9  <= checksum_adder(checksum_udp_data[31:0], checksum_udp_data[63:32]);
        checksum_tmp10 <= checksum_adder(checksum_tmp4, checksum_tmp5);
        checksum_tmp11 <= checksum_adder(checksum_tmp6, checksum_tmp7);
		    checksum_tmp12 <= checksum_adder(checksum_tmp8, checksum_tmp9);
        checksum_tmp13 <= checksum_adder(checksum_tmp10, checksum_tmp11);
		    checksum_tmp14 <= checksum_adder(checksum_tmp12, checksum_tmp13);
        
      end
    else if (ck_state == CK_IDLE)
      begin
        checksum_tmp4   <= 17'd0 ;
        checksum_tmp5   <= 17'd0 ;
        checksum_tmp6   <= 17'd0 ;
        checksum_tmp7   <= 17'd0 ;
        checksum_tmp8   <= 17'd0 ;
        checksum_tmp9   <= 32'd0 ;
        checksum_tmp10  <= 32'd0 ;
        checksum_tmp11  <= 32'd0 ;
        checksum_tmp12  <= 32'd0 ;
		checksum_tmp13	<= 32'd0 ;
        checksum_tmp14	<= 32'd0 ;

      end
      
  end

always @(posedge tx_axis_aclk)
  begin
    if(~tx_axis_areset)
	begin
      checksum_tmp0  <= 32'd0 ;
	  checksum_tmp1 <= 32'd0 ;
	  checksum_tmp2 <= 32'd0 ;
	  checksum_tmp3 <= 32'd0 ;
	end
    else if (udp_tx_axis_tvalid & udp_tx_axis_tready)
      begin
		if (udp_tx_axis_tlast)
		begin				
			case(udp_tx_axis_tkeep)
			8'b00000001: 
				  begin		
					checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],8'd0}, checksum_tmp0);		  
				  end
			8'b00000011:
				  begin
					checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],udp_tx_axis_tdata[15:8]}, checksum_tmp0);		  
				  end
			8'b00000111: 
				 begin
					checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],udp_tx_axis_tdata[15:8]}, checksum_tmp0);		  
					checksum_tmp1  <= checksum_adder({udp_tx_axis_tdata[23:16],8'd0}, checksum_tmp1);
				  end
			8'b00001111: 
				  begin
					checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],udp_tx_axis_tdata[15:8]}, checksum_tmp0);		  
					checksum_tmp1  <= checksum_adder({udp_tx_axis_tdata[23:16],udp_tx_axis_tdata[31:24]}, checksum_tmp1);
				  end
			8'b00011111: 
				  begin
					checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],udp_tx_axis_tdata[15:8]}, checksum_tmp0);		  
					checksum_tmp1  <= checksum_adder({udp_tx_axis_tdata[23:16],udp_tx_axis_tdata[31:24]}, checksum_tmp1);
					checksum_tmp2  <= checksum_adder({udp_tx_axis_tdata[39:32],8'd0}, checksum_tmp2);		
				  end
			8'b00111111:
				  begin
					checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],udp_tx_axis_tdata[15:8]}, checksum_tmp0);		  
					checksum_tmp1  <= checksum_adder({udp_tx_axis_tdata[23:16],udp_tx_axis_tdata[31:24]}, checksum_tmp1);
					checksum_tmp2  <= checksum_adder({udp_tx_axis_tdata[39:32],udp_tx_axis_tdata[47:40]}, checksum_tmp2);
				  end
			8'b01111111:
				  begin
					checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],udp_tx_axis_tdata[15:8]}, checksum_tmp0);		  
					checksum_tmp1  <= checksum_adder({udp_tx_axis_tdata[23:16],udp_tx_axis_tdata[31:24]}, checksum_tmp1);
					checksum_tmp2  <= checksum_adder({udp_tx_axis_tdata[39:32],udp_tx_axis_tdata[47:40]}, checksum_tmp2);
					checksum_tmp3  <= checksum_adder({udp_tx_axis_tdata[55:48],8'd0}, checksum_tmp3);
				
				  end
			8'b11111111:
				  begin
					checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],udp_tx_axis_tdata[15:8]}, checksum_tmp0);		  
					checksum_tmp1  <= checksum_adder({udp_tx_axis_tdata[23:16],udp_tx_axis_tdata[31:24]}, checksum_tmp1);
					checksum_tmp2  <= checksum_adder({udp_tx_axis_tdata[39:32],udp_tx_axis_tdata[47:40]}, checksum_tmp2);
					checksum_tmp3  <= checksum_adder({udp_tx_axis_tdata[55:48],udp_tx_axis_tdata[63:56]}, checksum_tmp3);
				
				  end
			default: begin
						checksum_tmp0   <= checksum_tmp0  ;
						checksum_tmp1  <= checksum_tmp1 ;
						checksum_tmp2  <= checksum_tmp2 ;
						checksum_tmp3  <= checksum_tmp3 ;				
					 end
			endcase		
		end
		else
		begin
          checksum_tmp0   <= checksum_adder({udp_tx_axis_tdata[7:0],udp_tx_axis_tdata[15:8]}, checksum_tmp0);		  
		  checksum_tmp1  <= checksum_adder({udp_tx_axis_tdata[23:16],udp_tx_axis_tdata[31:24]}, checksum_tmp1);
		  checksum_tmp2  <= checksum_adder({udp_tx_axis_tdata[39:32],udp_tx_axis_tdata[47:40]}, checksum_tmp2);
		  checksum_tmp3  <= checksum_adder({udp_tx_axis_tdata[55:48],udp_tx_axis_tdata[63:56]}, checksum_tmp3);		  
		end
	end
	else if (~udp_tx_axis_tlast & udp_tx_axis_tlast_d0)
	begin
		checksum_tmp0  <= 32'd0 ;
		checksum_tmp1 <= 32'd0 ;
		checksum_tmp2 <= 32'd0 ;
		checksum_tmp3 <= 32'd0 ;
	end
  end

always @(posedge tx_axis_aclk)
  begin
    if(~tx_axis_areset)
	begin
      checksum_d0  <= 32'd0 ;
	  checksum_d1 <= 32'd0 ;
	end
	else
	begin
      checksum_d0  <= checksum_adder(checksum_tmp0, checksum_tmp1);
	  checksum_d1  <= checksum_adder(checksum_tmp2, checksum_tmp3);
	end
  end
/* checksum counter  */
always @(posedge tx_axis_aclk)
  begin
    if(~tx_axis_areset)
      checksum_cnt <= 6'd0 ;
    else if (ck_state ==  GEN_CHECKSUM )
      checksum_cnt <= checksum_cnt + 1'b1 ;
	else
	  checksum_cnt <= 6'd0 ;
  end




always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
	begin
      checksum_buf <= 32'd0;
	  checksum_buf_dly <= 32'd0;
	end
    else if (ck_state == GEN_CHECKSUM )
	begin
      checksum_buf <= checksum_out(checksum_tmp14) ;
	  checksum_buf_dly <= checksum_out(checksum_buf) ;
	end
  end

assign checksum = ~checksum_buf_dly[15:0] ;   
  
  

/* checksum fifo write enable  */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      checksum_wr <= 1'b0 ;
    else if (ck_state == GEN_CHECKSUM_END & ~checksum_fifo_almost_full)
      checksum_wr <= 1'b1 ;
    else
      checksum_wr <= 1'b0 ;
  end
/* length fifo read enable  */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      length_fifo_rden <= 1'b0 ;
    else if (ck_state == CK_IDLE && ck_state != ck_next_state)
      length_fifo_rden <= 1'b1 ;
    else
      length_fifo_rden <= 1'b0 ;
  end

/* udp length and data checksum from length fifo  */  
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
	begin
      checksum_udp_len <= 16'd0 ;
	  checksum_udp_data <= 64'd0 ;
	end
    else if ((ck_state == UDP_LENGTH_READY) && (ck_state != ck_next_state))
	begin
      checksum_udp_len <= length_rd_data[15:0]+8 ;
	  checksum_udp_data <= length_rd_data[79:16] ;
	end
  end
/* data write to checksum fifo  */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      checksum_in <= 32'd0 ;
    else if (ck_state == GEN_CHECKSUM_END)
      checksum_in <= {checksum_udp_len, checksum } ;
    else
      checksum_in <= 32'd0 ;
  end  
 


/* sync fifo for udp checksum */
 std_fwft_fifo 
#(
  .WIDTH(32) ,
  .DEPTH(5),
  .FIFO_TYPE("fwft")
)
udp_tx_checksum
(
  .clk       (tx_axis_aclk   ),
  .rst_n     (tx_axis_areset ),
  .wren      (checksum_wr     ),
  .rden      (checksum_rd     ),
  .data      (checksum_in     ),
  .q         (checksum_q      ),
  .full      (checksum_fifo_full ),
  .empty     (checksum_fifo_empty ),
  .almost_full	(checksum_fifo_almost_full)
) ;


assign udp_not_empty = ~checksum_fifo_empty ;

/**********************************************************************************
*Thrid : When checksum fifo is not empty, then read out frame
***********************************************************************************/
localparam IDLE              = 2'd0 ;
localparam SEND_WAIT         = 2'd1 ;
localparam SEND_DATA         = 2'd2 ;



reg [1:0]    state  ;
reg [1:0]    next_state ;


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
      IDLE            :
        begin
          if (udp_not_empty & ip_tx_axis_tready)    //when udp is ready and ip tready is valid, start to send udp data to ip layer
            next_state <= SEND_WAIT ;
          else
            next_state <= IDLE ;
        end		
	  SEND_WAIT   :
		    next_state <= SEND_DATA ;
      SEND_DATA       :
        begin
          if (ip_tx_axis_tready & ip_tx_axis_tvalid & ip_tx_axis_tlast)
            next_state <= IDLE ;
          else
            next_state <= SEND_DATA ; 	
        end
      default        :
        next_state <= IDLE ;
    endcase
  end


/* Read out checksum when send data to ip layer  */ 
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      checksum_rd <= 1'b0 ;
    else if (state == IDLE && state != next_state)
      checksum_rd <= 1'b1 ;
    else
      checksum_rd <= 1'b0 ;
  end


/* stream counter  */    
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      udp_stream_cnt <= 8'd0 ;
	else if (ip_tx_axis_tready & ip_tx_axis_tvalid)
	begin
		if (state == SEND_DATA)
			udp_stream_cnt <= udp_stream_cnt + 1'b1 ;
		else
			udp_stream_cnt <= 1'b0 ;
	end
	else if  (state == IDLE)
		udp_stream_cnt <= 8'd0 ;
  end
/* stream length and udp checksum   */ 	   
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
    begin
	  udp_checksum <= 16'd0 ;
      udp_data_byte <= 16'd0 ;
    end
    else if (state == SEND_WAIT)
	begin
      udp_data_byte <= checksum_q[31:16] ;
	  udp_checksum <= checksum_q[15:0] ;
	end
  end

  
assign  udp_fifo_rden = (state == SEND_DATA) & ip_tx_axis_tready & (|udp_stream_cnt) & ~udp_fifo_empty;
  
always @(*)
  begin
	if (state == SEND_DATA)
    begin
		if (~(|udp_stream_cnt))
		begin
			ip_tx_axis_tdata <= {udp_checksum[7:0],udp_checksum[15:8],udp_data_byte[7:0],udp_data_byte[15:8],
								udp_dst_port[7:0],udp_dst_port[15:8],udp_src_port[7:0],udp_src_port[15:8]};
			ip_tx_axis_tkeep <= 8'hff ;
			ip_tx_axis_tvalid <= 1'b1 ;
			ip_tx_axis_tlast <= 1'b0 ;
		end
		else
		begin
			ip_tx_axis_tdata <= udp_fifo_rdata[73:10];
			ip_tx_axis_tkeep <= udp_fifo_rdata[9:2] ;
			ip_tx_axis_tvalid <= udp_fifo_rdata[1] ;
			ip_tx_axis_tlast <= udp_fifo_rdata[0] ;
		end
	end
	else
	begin
      ip_tx_axis_tdata <= 64'd0;
	  ip_tx_axis_tkeep <= 8'd0 ;
	  ip_tx_axis_tvalid <= 1'b0 ;
	  ip_tx_axis_tlast <= 1'b0 ;
	end
  end	   
  
endmodule



// IP Decryptor end

