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
//   Description:  frame transmit module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//  2020/12/27    myj          1.1         use pkg_fifo_almost_full to control package data and support jumbo frame
//********************************************************************************/


module frame_tx
	#(
		parameter StreamWidth = 64
	)
	(
		input [47:0]						     src_mac_addr,
		input [47:0]						     dst_mac_addr,
		input [15:0]						     protocol_type,		
		
		input                            	     tx_axis_aclk,
        input                            	     tx_axis_areset,
		/* frame tx axis interface */
        input  [StreamWidth-1:0]       	     	 frame_tx_axis_tdata,
        input  [StreamWidth/8-1:0]     	     	 frame_tx_axis_tkeep,
        input                            	     frame_tx_axis_tvalid,		 
        input                            	     frame_tx_axis_tlast,
        output                           	     frame_tx_axis_tready,
		/* tx axis interface to mac */
		output reg  [StreamWidth-1:0]       	 mac_tx_axis_tdata,
		output reg  [StreamWidth/8-1:0]     	 mac_tx_axis_tkeep,
		output reg            				     mac_tx_axis_tvalid,	
		output reg            				     mac_tx_axis_tlast,
        input                				     mac_tx_axis_tready,
		
		 output								     rcv_stream_end			//receive stream end signal

    );
	

/**************************************************************
*First : storage stream data and record byte length or something
**************************************************************/
reg						            stream_byte_rden 		; 	//byte fifo read enable signal
wire [15:0]				            stream_byte_rdata 	  	;	//byte fifo read data
wire								stream_byte_fifo_empty ;	//byte fifo empty
            
wire					    	    stream_data_rden  ;	  //data fifo read enable signal
wire [73:0]           	            stream_data_rdata ;   //data fifo read data                            


reg [15:0]							frame_type ;		  //frame type : ip or arp


/* Receiver stream data from ip or arp */
stream_to_fifo
	#(
		.TransType("FRAME")
	)
	frame_stream_inst
	(
	.tx_type				   (protocol_type			),		
	.tx_axis_aclk              (tx_axis_aclk            ),
    .tx_axis_areset   		   (tx_axis_areset   		),			
	.tx_axis_tdata             (frame_tx_axis_tdata     ),
    .tx_axis_tkeep             (frame_tx_axis_tkeep     ),
    .tx_axis_tvalid 		   (frame_tx_axis_tvalid 	), 
    .tx_axis_tlast             (frame_tx_axis_tlast     ),
    .tx_axis_tready 		   (frame_tx_axis_tready 	), 
	.stream_byte_fifo_empty    (stream_byte_fifo_empty	),		
	.stream_byte_rden	       (stream_byte_rden	    ),
	.stream_byte_rdata 	       (stream_byte_rdata 	    ),	 
	.stream_data_rden          (stream_data_rden        ),
	.stream_data_rdata  	   (stream_data_rdata  	    ),		 
	.rcv_stream_end            (rcv_stream_end          )
    );

/***************************************************************************************
*Second : After stream received, then package data with frame head and store into fifo
***************************************************************************************/
reg 					pkg_wren 		;	//package fifo write enable
wire					pkg_rden 		;   //package fifo read enable
reg [73:0]				pkg_wdata 		;   //package fifo write data
wire [73:0]				pkg_rdata 		;   //package fifo read data
wire					pkg_fifo_full 	;   //package fifo full
wire					pkg_fifo_empty 		 ;  //package fifo empty
wire					pkg_fifo_almost_full ;	//package fifo almost full, there is only one data can be wirte into fifo

/* axis interface */
wire [63:0]				stream_data ; 
wire [7:0]				stream_keep ;
wire 					stream_valid;
wire 					stream_last ;
/* register for data and keep */
reg [63:0]				stream_data_dly ;
reg [7:0]				stream_keep_dly ;

/* package stream data into fifo, after add header */  
localparam PKG_IDLE         = 7'b0000001 ;
localparam PKG_WAIT         = 7'b0000010 ;
localparam PKG_ADDR         = 7'b0000100 ;	//package mac address state
localparam PKG_ADDR_LT      = 7'b0001000 ;	//package mac address and length/type state
localparam PKG_DATA         = 7'b0010000 ;
localparam PKG_LAST_ONE     = 7'b0100000 ;
localparam PKG_END		    = 7'b1000000 ;


reg [6:0]    pkg_state  ;
reg [6:0]    pkg_next_state ;



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
          if (~stream_byte_fifo_empty)
            pkg_next_state <= PKG_WAIT ;
          else
            pkg_next_state <= PKG_IDLE ;
        end		

	  PKG_WAIT   :
		    pkg_next_state <= PKG_ADDR ;
	
	  PKG_ADDR      :
        begin
          if (~pkg_fifo_almost_full)
            pkg_next_state <= PKG_ADDR_LT ;
          else
            pkg_next_state <= PKG_ADDR ; 	
        end
	  PKG_ADDR_LT      :
        begin
          if (~pkg_fifo_almost_full)
            pkg_next_state <= PKG_DATA ;
          else
            pkg_next_state <= PKG_ADDR_LT ; 	
        end
			
      PKG_DATA       :
		  begin			
			if (~pkg_fifo_almost_full & stream_valid & stream_last & (|stream_keep[7:2]))   /* if last keep bigger than 2 data counter, switch to PKG_LAST_ONE state */
				pkg_next_state <= PKG_LAST_ONE ;			
			else if (~pkg_fifo_almost_full & stream_valid & stream_last & ~(|stream_keep[7:2]))  /* if last keep less than 2 data counter, switch to PKG_END state */
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



/* read word data  */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
	begin
	  stream_byte_rden <= 1'b0 ;
	end
    else if (pkg_state == PKG_IDLE && pkg_state != pkg_next_state)
	begin
	  stream_byte_rden <= 1'b1 ;
	end
    else
    begin
	  stream_byte_rden <= 1'b0 ;
	end
  end
 
/* register for type  */    
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
	begin
	  frame_type <= 16'd0 ;
	end
    else if (pkg_state == PKG_WAIT)
	begin
	  frame_type <= stream_byte_rdata ;
	end
  end

 
assign stream_data_rden = (pkg_state == PKG_ADDR_LT || pkg_state == PKG_DATA) & (~pkg_fifo_almost_full) ; 
/* package fifo write enable control */ 
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      pkg_wren <= 1'b0 ;
    else if (~pkg_fifo_almost_full)
	begin
		if (pkg_state == PKG_ADDR || pkg_state == PKG_ADDR_LT || pkg_state == PKG_DATA || pkg_state == PKG_LAST_ONE)
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

/* sync fifo for udp data */
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
  .data      (pkg_wdata			),
  .q         (pkg_rdata    		),
  .full      (pkg_fifo_full  	),
  .empty     (pkg_fifo_empty ),
  .almost_full  	(pkg_fifo_almost_full)
) ;  

   // Form pkg_wdata here
   // opreg7to0

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR      		: pkg_wdata[7:0]    <= 8'hff;
         PKG_ADDR_LT 		: pkg_wdata[7:0]    <= 8'hff;
         PKG_DATA      		: begin
								if (stream_valid & stream_last)
								begin
									if (~(|stream_keep[7:2]))										
										pkg_wdata[7:0]    <= stream_keep<<6 | 8'h3f;
									else
										pkg_wdata[7:0]    <= 8'hff;
								end
								else
									pkg_wdata[7:0]    <= 8'hff;
							  end
         PKG_LAST_ONE      	: begin
								pkg_wdata[7:0]    <= stream_keep_dly>>2;
							  end
         PKG_IDLE      		: pkg_wdata[7:0]    <= 8'h00;
         default   			: pkg_wdata[7:0]    <= 8'h00;
      endcase
   end

   // opreg15to8

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR      		: pkg_wdata[15:8]   <= dst_mac_addr[47:40];
         PKG_ADDR_LT 		: pkg_wdata[15:8]   <= src_mac_addr[31:24];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[15:8]   <= stream_data_dly[23:16];
		 PKG_LAST_ONE		: if (~pkg_fifo_almost_full) pkg_wdata[15:8]   <= stream_data_dly[23:16];
         PKG_IDLE     		: pkg_wdata[15:8]   <= 8'h00;
         default   			: pkg_wdata[15:8]   <= 8'h00;
      endcase
   end

   // opreg23to16

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR      		: pkg_wdata[23:16]  <= dst_mac_addr[39:32];
         PKG_ADDR_LT 		: pkg_wdata[23:16]  <= src_mac_addr[23:16];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[23:16]  <= stream_data_dly[31:24];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[23:16]  <= stream_data_dly[31:24];
         PKG_IDLE      		: pkg_wdata[23:16]  <= 8'h00;
         default   			: pkg_wdata[23:16]  <= 8'h00;
      endcase
   end

   // opreg31to24

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR      		: pkg_wdata[31:24]  <= dst_mac_addr[31:24];
         PKG_ADDR_LT 		: pkg_wdata[31:24]  <= src_mac_addr[15:8];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[31:24]  <= stream_data_dly[39:32];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[31:24]  <= stream_data_dly[39:32];
         PKG_IDLE      		: pkg_wdata[31:24]  <= 8'h00;
         default  			: pkg_wdata[31:24]  <= 8'h00;
      endcase
   end

   // opreg39to32

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR      		: pkg_wdata[39:32]  <= dst_mac_addr[23:16];
         PKG_ADDR_LT 		: pkg_wdata[39:32]  <= src_mac_addr[7:0];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[39:32]  <= stream_data_dly[47:40];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[39:32]  <= stream_data_dly[47:40];
         PKG_IDLE      		: pkg_wdata[39:32]  <= 8'h00;
         default   			: pkg_wdata[39:32]  <= 8'h00;
      endcase
   end

   // opreg47to40

always @(posedge tx_axis_aclk)
   begin
       case (pkg_state)
         PKG_ADDR      		: pkg_wdata[47:40]  <= dst_mac_addr[15:8];
         PKG_ADDR_LT 		: pkg_wdata[47:40]  <= frame_type[15:8];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[47:40]  <= stream_data_dly[55:48];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[47:40]  <= stream_data_dly[55:48];
         PKG_IDLE      		: pkg_wdata[47:40]  <= 8'h00;
         default   			: pkg_wdata[47:40]  <= 8'h00;
      endcase
   end

   // opreg55to48

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR      		: pkg_wdata[55:48]  <= dst_mac_addr[7:0];
         PKG_ADDR_LT 		: pkg_wdata[55:48]  <= frame_type[7:0];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[55:48]  <= stream_data_dly[63:56];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[55:48]  <= stream_data_dly[63:56];
         PKG_IDLE      		: pkg_wdata[55:48]  <= 8'h00;
         default   			: pkg_wdata[55:48]  <= 8'h00;
      endcase
   end

   // opreg63to56

always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR      		: pkg_wdata[63:56]  <= src_mac_addr[47:40];
         PKG_ADDR_LT 		: if (~pkg_fifo_almost_full) pkg_wdata[63:56]  <= stream_data[7:0];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[63:56]  <= stream_data[7:0];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[63:56]  <= stream_data[7:0];
         PKG_IDLE      		: pkg_wdata[63:56]  <= 8'h00;
         default   			: pkg_wdata[63:56]  <= 8'h00;
      endcase
   end	
   // opreg71to64
always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR      		: pkg_wdata[71:64]  <= src_mac_addr[39:32];
         PKG_ADDR_LT 		: if (~pkg_fifo_almost_full) pkg_wdata[71:64]  <= stream_data[15:8];
         PKG_DATA      		: if (~pkg_fifo_almost_full) pkg_wdata[71:64]  <= stream_data[15:8];
		 PKG_LAST_ONE      	: if (~pkg_fifo_almost_full) pkg_wdata[71:64]  <= stream_data[15:8];
         PKG_IDLE      		: pkg_wdata[71:64]  <= 8'h00;
         default   			: pkg_wdata[71:64]  <= 8'h00;
      endcase
   end	

  // opreg73 to 72  bit73 equals to tvalid; bit72 equals to tlast
always @(posedge tx_axis_aclk)
   begin
      case (pkg_state)
         PKG_ADDR       	: pkg_wdata[73:72]    <= 2'b10;
         PKG_ADDR_LT  		: pkg_wdata[73:72]    <= 2'b10;
         PKG_DATA     		: begin
								if (stream_valid & stream_last)
								begin
									if (~(|stream_keep[7:2]))			//last word has bytes less than 2							
										pkg_wdata[73:72]    <= 2'b11;
									else
										pkg_wdata[73:72]    <= 2'b10;
								end
								else
									pkg_wdata[73:72]    <= 2'b10;
							  end
         PKG_LAST_ONE      	: begin
								pkg_wdata[73:72]    <= 2'b11;
							  end
         PKG_IDLE      		: pkg_wdata[73:72]    <= 2'b00;
         default   			: pkg_wdata[73:72]    <= 2'b00;
      endcase
   end

/**********************************************************************************
*Thrid : When there package fifo is not empty, then read out frame
***********************************************************************************/
  
localparam MAC_IDLE              = 2'b01 ;
localparam MAC_SEND_DATA         = 2'b10 ;



reg [1:0]    mac_state  ;
reg [1:0]    mac_next_state ;


always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_areset)
      mac_state  <=  MAC_IDLE  ;
    else
      mac_state  <= mac_next_state ;
  end
  
always @(*)
    begin
      case(mac_state)
        MAC_IDLE            :
          begin
            if (~pkg_fifo_empty)
              mac_next_state <= MAC_SEND_DATA ;
            else
              mac_next_state <= MAC_IDLE ;
          end        
        MAC_SEND_DATA       :
          begin
            if (mac_tx_axis_tready & mac_tx_axis_tvalid & mac_tx_axis_tlast)
              mac_next_state <= MAC_IDLE ;
            else
              mac_next_state <= MAC_SEND_DATA ;     
          end
        default        :
          mac_next_state <= MAC_IDLE ;
      endcase
    end  
  
  
  assign pkg_rden = (mac_state == MAC_SEND_DATA) & mac_tx_axis_tready & (~pkg_fifo_empty);
  
  
  always @(*)
    begin
      if (mac_state == MAC_SEND_DATA)
      begin
          mac_tx_axis_tdata <= pkg_rdata[71:8];
          mac_tx_axis_tkeep <= pkg_rdata[7:0] ;
          mac_tx_axis_tvalid <= pkg_rdata[73] ;
          mac_tx_axis_tlast <= pkg_rdata[72] ;
      end
      else
      begin
          mac_tx_axis_tdata <= {StreamWidth{1'b0}};
          mac_tx_axis_tkeep <= {(StreamWidth/8){1'b0}} ;
          mac_tx_axis_tvalid <= 1'b0 ;
          mac_tx_axis_tlast  <= 1'b0 ;
      end
    end


	
endmodule



// IP Decryptor end

