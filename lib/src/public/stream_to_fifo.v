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
//   Description:  puts stream data into fifo
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//  2020/12/16     myj         1.1         support jumbo frame
//********************************************************************************/


module stream_to_fifo
	#(
		parameter TransType = "IP",
		parameter StreamFIFOWidth = 74,		//do not modify  tdata(64)+tvalid(1)+tlast(1)
		parameter StreamFIFODepth = 11,
		parameter StreamCountWidth = 16,	//do not modify
		parameter StreamCountDepth = 3,
		parameter StreamWidth =64			//do not modify
	)
	(
		 input 	[StreamCountWidth-1:0]					tx_type,				//type: arp type, ip type and so on									
		 input                							tx_axis_aclk,
         input                							tx_axis_areset,  
		/* axis interface */			
		 input  [StreamWidth-1:0]        				tx_axis_tdata,
         input  [StreamWidth/8-1:0]     	  			tx_axis_tkeep,
         input                							tx_axis_tvalid,		 
         input                							tx_axis_tlast,
         output 	           							tx_axis_tready,
			
		 input 											stream_byte_rden	  ,	//byte fifo read enable signal
		 output [StreamCountWidth*2-1:0]				stream_byte_rdata 	  ,	//byte fifo read data
		 output											stream_byte_fifo_empty,	//byte fifo empty		 
		 input											stream_data_rden ,		//data fifo read enable signal
		 output [StreamFIFOWidth-1:0]           		stream_data_rdata ,		//data fifo read data	
		 output reg										rcv_stream_end			//stream received end signal
    );


reg										stream_byte_wren ;				//byte fifo write enable signal
wire [StreamCountWidth-1:0]				stream_byte_len		  ;			//byte length signal
wire									stream_byte_fifo_full ;			//byte fifo full signal
wire									stream_byte_fifo_almost_full ;	//byte fifo almost full, when assert, only one data can be write in fifo

wire									stream_data_fifo_full ;			//data fifo full signal
wire									stream_data_fifo_almost_full ;	//data fifo almost full signal, when assert, only one data can be write in fifo
reg										stream_data_wren ;				//data fifo write enable signal
reg [StreamFIFOWidth-1:0]           	stream_data_wdata ;				//data fifo write data

reg [7:0]								last_tkeep ;					//last tkeep signal, not used
reg [15:0]								trans_type ;					//type latch for tx_type
/* Receiver stream data from udp or icmp FSM */
localparam IDLE               = 4'b0001 ;
localparam STREAM	     	  = 4'b0010 ;
localparam STREAM_END   	  = 4'b0100 ;
localparam STREAM_END_WAIT	  = 4'b1000 ;



reg [3:0]    state  ;
reg [3:0]    next_state ;

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
           next_state <= STREAM ;
	  STREAM  :
		begin
          if (tx_axis_tvalid & tx_axis_tready &tx_axis_tlast)
            next_state <= STREAM_END ;
          else
            next_state <= STREAM ;
        end 
	  STREAM_END  : 
		begin
			if (~stream_byte_fifo_almost_full)
				next_state <= STREAM_END_WAIT ;
			else
				next_state <= STREAM_END ;
		end
	  STREAM_END_WAIT :
			next_state <= IDLE ;
	  default          :
        next_state <= IDLE ;
	endcase
  end
/* latch for tx_type */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      trans_type <= 16'd0 ;
    else if (state == STREAM)
      trans_type <= tx_type ;
  end 

assign tx_axis_tready = (state == STREAM) & ~(stream_data_fifo_almost_full | stream_byte_fifo_almost_full) ;
/* stream received end signal */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      rcv_stream_end <= 1'b0 ;
    else if (state == STREAM_END)
      rcv_stream_end <= 1'b1 ;
    else
      rcv_stream_end <= 1'b0 ;
  end 


/* Write stream enable signal */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      stream_data_wren  <= 1'b0 ;
    else if (state == STREAM && tx_axis_tvalid == 1'b1 && tx_axis_tready == 1'b1)
      stream_data_wren  <= 1'b1 ;
	else
	  stream_data_wren  <= 1'b0 ;
  end 
/* Write stream data to fifo */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      stream_data_wdata <= {StreamFIFOWidth{1'b0}} ;
    else if (state == STREAM && tx_axis_tvalid == 1'b1 && tx_axis_tready == 1'b1)
      stream_data_wdata  <= {tx_axis_tdata,tx_axis_tkeep,tx_axis_tvalid,tx_axis_tlast} ;
  end
 


/* stream counter write enable */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
	begin
	  stream_byte_wren   <= 1'b0 ;
	end
    else if (state == STREAM_END && ~(stream_byte_fifo_almost_full))
	begin
	  stream_byte_wren   <= 1'b1 ;
	end
	else
	begin
	  stream_byte_wren   <= 1'b0 ;
	end
  end 
 

 
stream_counter stream_inst
      (       
		.axis_aclk          (tx_axis_aclk),
        .axis_areset     	(tx_axis_areset), 			
		.axis_tdata         (tx_axis_tdata),
        .axis_tkeep         (tx_axis_tkeep),
        .axis_tvalid 	    (tx_axis_tvalid),
        .axis_tlast         (tx_axis_tlast),
        .axis_tready 	  	(tx_axis_tready), 		
		.stream_byte_len    (stream_byte_len),
		.stream_word_len    ()
      ) ;
 
/* sync fifo for stream data  */
 std_fwft_fifo 
#(
  .WIDTH(StreamFIFOWidth) ,
  .DEPTH(StreamFIFODepth),
  .FIFO_TYPE("fwft")
)
stream_data_fifo
(
  .clk       (tx_axis_aclk   ),
  .rst_n     (tx_axis_areset ),
  .wren      (stream_data_wren),
  .rden      (stream_data_rden  ),
  .data      (stream_data_wdata),
  .q         (stream_data_rdata ),
  .full      (stream_data_fifo_full),
  .almost_full  	(stream_data_fifo_almost_full),
  .empty     ( 	)
) ; 


/* sync fifo for byte length  */
generate
if (TransType == "IP")

	std_fwft_fifo 
	#(
	.WIDTH(32) ,
	.DEPTH(StreamCountDepth),
	.FIFO_TYPE("fwft")
	)
	stream_byte_fifo
	(
	.clk       (tx_axis_aclk   ),
	.rst_n     (tx_axis_areset ),
	.wren      (stream_byte_wren		),
	.rden      (stream_byte_rden  	),
	.data      ({trans_type,stream_byte_len}),
	.q         (stream_byte_rdata 	),
	.full      (stream_byte_fifo_full ),
	.empty     (stream_byte_fifo_empty 	),
	.almost_full  (stream_byte_fifo_almost_full)
	) ;  
else if (TransType == "FRAME")
	std_fwft_fifo 
	#(
	.WIDTH(16) ,
	.DEPTH(StreamCountDepth),
	.FIFO_TYPE("fwft")
	)
	stream_byte_fifo
	(
	.clk       (tx_axis_aclk   ),
	.rst_n     (tx_axis_areset ),
	.wren      (stream_byte_wren		),
	.rden      (stream_byte_rden  	),
	.data      (trans_type),
	.q         (stream_byte_rdata 	),
	.full      (stream_byte_fifo_full ),
	.empty     (stream_byte_fifo_empty 	),
	.almost_full  (stream_byte_fifo_almost_full)
	) ; 
endgenerate

endmodule



// IP Decryptor end

