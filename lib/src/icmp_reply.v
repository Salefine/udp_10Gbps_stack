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
//   Description:  icmp receive and reply module
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/8/27     myj          1.0         Original
//********************************************************************************/


module icmp_reply(
		input                              rx_axis_aclk,
		input                              rx_axis_areset,
		/* ip rx axis interface */
		input [63:0]       	     		   ip_rx_axis_tdata,
        input [7:0]     	     		   ip_rx_axis_tkeep,
        input                              ip_rx_axis_tvalid,		 
        input                              ip_rx_axis_tlast,
        input                          	   ip_rx_axis_tusr,
		/* icmp tx axis interface */
		output reg [63:0]       	   	   icmp_tx_axis_tdata,
        output reg [7:0]     	     	   icmp_tx_axis_tkeep,
        output reg                         icmp_tx_axis_tvalid,		 
        output reg                         icmp_tx_axis_tlast,
        input 	                           icmp_tx_axis_tready,
		
		output reg						   icmp_not_empty	//icmp is ready to send data
		
		

    );
	

localparam ECHO_REQUEST = 8'h08 ;
localparam ECHO_REPLY   = 8'h00 ;

wire							empty ;

reg  [7:0]             			icmp_type  ;              //icmp type
reg  [7:0]             			icmp_code  ;              //icmp code
reg  [15:0]            			icmp_id  ;                //icmp id
reg  [15:0]            			icmp_seq ;                //icmp seq
reg  [15:0]            			icmp_checksum ;           //icmp checksum

reg [63:0]       	     		icmp_tdata ;
reg [7:0]     	     			icmp_tkeep ;
reg                           	icmp_tvalid ;		 
reg                           	icmp_tlast ;
reg                          	icmp_tusr  ;
wire [63:0]       	     		icmp_fifo_axis_tdata ;
wire [7:0]     	     			icmp_fifo_axis_tkeep ;
wire                           	icmp_fifo_axis_tvalid ;		 
wire                           	icmp_fifo_axis_tlast ;
wire                          	icmp_fifo_axis_tusr  ;
/* icmp receive FSM */
localparam ICMP_RCV_HEAD      		= 7'b0000001 ;	//receive head state
localparam ICMP_RCV_DATA    		= 7'b0000010 ;  //receive data state
localparam ICMP_RCV_GOOD     		= 7'b0000100 ;  
localparam ICMP_RCV_BAD     		= 7'b0001000 ;  
localparam ICMP_GOOD_FRAME_HEAD     = 7'b0010000 ;  //send head state
localparam ICMP_GOOD_FRAME     		= 7'b0100000 ;  //send data state
localparam ICMP_BAD_FRAME     		= 7'b1000000 ;  


reg [6:0]    rcv_state  ;
reg [6:0]    rcv_next_state ;



always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
      rcv_state  <=  ICMP_RCV_HEAD  ;
    else
      rcv_state  <= rcv_next_state ;
  end
  
always @(*)
  begin
    case(rcv_state)
      ICMP_RCV_HEAD            :
        begin
          if (ip_rx_axis_tvalid & ~ip_rx_axis_tlast)
            rcv_next_state <= ICMP_RCV_DATA ;
		  else if (ip_rx_axis_tvalid & ip_rx_axis_tlast)
			rcv_next_state <= ICMP_RCV_BAD ;
          else
            rcv_next_state <= ICMP_RCV_HEAD ;
        end		
	  ICMP_RCV_DATA     :
        begin
		  if (icmp_type == ECHO_REQUEST)
		  begin
			if (ip_rx_axis_tvalid & ip_rx_axis_tlast & ip_rx_axis_tusr)
				rcv_next_state <= ICMP_RCV_GOOD ;
			else if (ip_rx_axis_tvalid & ip_rx_axis_tlast & ~ip_rx_axis_tusr)
				rcv_next_state <= ICMP_RCV_BAD ; 	
			else
				rcv_next_state <= ICMP_RCV_DATA ;
		  end
		  else
		  begin
			if (ip_rx_axis_tvalid & ip_rx_axis_tlast)
				rcv_next_state <= ICMP_RCV_HEAD ;
			else
				rcv_next_state <= ICMP_RCV_DATA ;
		  end
        end
	  ICMP_RCV_GOOD      :
		begin
			if (icmp_fifo_axis_tvalid & icmp_fifo_axis_tlast & icmp_fifo_axis_tusr)
				rcv_next_state <= ICMP_GOOD_FRAME_HEAD ;
			else if (icmp_fifo_axis_tvalid & icmp_fifo_axis_tlast & ~icmp_fifo_axis_tusr)
				rcv_next_state <= ICMP_BAD_FRAME ;
			else
				rcv_next_state <= ICMP_RCV_GOOD ;
		end
		
	  ICMP_RCV_BAD     :
		begin
			if (icmp_fifo_axis_tvalid & icmp_fifo_axis_tlast)
				rcv_next_state <= ICMP_BAD_FRAME ;
            else
				rcv_next_state <= ICMP_RCV_BAD ;
	    end
	  ICMP_GOOD_FRAME_HEAD      :
		begin
			if (icmp_tx_axis_tvalid & icmp_tx_axis_tready)
				rcv_next_state <= ICMP_GOOD_FRAME ;
			else
				rcv_next_state <= ICMP_GOOD_FRAME_HEAD ;
		end
	  ICMP_GOOD_FRAME      :
		begin
			if (icmp_tx_axis_tvalid & icmp_tx_axis_tready & icmp_tx_axis_tlast)
				rcv_next_state <= ICMP_RCV_HEAD ;
			else
				rcv_next_state <= ICMP_GOOD_FRAME ;
		end
	  ICMP_BAD_FRAME      :
		begin
			if (empty)
				rcv_next_state <= ICMP_RCV_HEAD ;
			else
				rcv_next_state <= ICMP_BAD_FRAME ;
		end
      default        :
        rcv_next_state <= ICMP_RCV_HEAD ;
    endcase
  end  	
/* register for head data */	
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		icmp_type  	 	 <= 8'd0 ;
		icmp_code 	 	 <= 8'd0 ;
		icmp_checksum 	 <= 16'd0 ;
		icmp_id   	 	 <= 16'd0 ;
		icmp_seq     	 <= 16'd0 ;
	end
	else if (rcv_state == ICMP_RCV_HEAD  && ip_rx_axis_tvalid)
	begin
		icmp_type 	 			<= ip_rx_axis_tdata[7:0] ;
		icmp_code  	 			<= ip_rx_axis_tdata[15:8] ;
		icmp_checksum[15:8]  	<= ip_rx_axis_tdata[23:16] ;
		icmp_checksum[7:0]  	<= ip_rx_axis_tdata[31:24] ;
		icmp_id[15:8]   		<= ip_rx_axis_tdata[39:32] ;
		icmp_id[7:0]  	 		<= ip_rx_axis_tdata[47:40] ;
		icmp_seq[15:8]  	 	<= ip_rx_axis_tdata[55:48] ;
		icmp_seq[7:0]  			<= ip_rx_axis_tdata[63:56] ;
	end
  end	

/* register for icmp stream data */
 always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		icmp_tdata  <= 64'd0 ;
		icmp_tkeep  <= 8'd0 ;
		icmp_tvalid <= 1'b0 ;
		icmp_tlast  <= 1'b0 ;
		icmp_tusr   <= 1'b0  ;
	end
	else if (rcv_state == ICMP_RCV_DATA  && ip_rx_axis_tvalid)
	begin
		icmp_tdata  <= ip_rx_axis_tdata ;
		icmp_tkeep  <= ip_rx_axis_tkeep;
		icmp_tvalid <= ip_rx_axis_tvalid;
		icmp_tlast  <= ip_rx_axis_tlast;
		icmp_tusr   <= ip_rx_axis_tusr ;
	end
	else
	begin
		icmp_tdata  <= 64'd0 ;
		icmp_tkeep  <= 8'd0 ;
		icmp_tvalid <= 1'b0 ;
		icmp_tlast  <= 1'b0 ;
		icmp_tusr   <= 1'b0  ;
	end
  end 

//****************************************************************//
//verify checksum
//****************************************************************//
reg  [16:0] checksum_tmp0 ;
reg  [16:0] checksum_tmp1 ;

reg  [31:0] checksum_tmp2 ;
reg  [31:0] checksum_tmp3 ;
reg  [31:0] checksum_tmp4 ;
reg  [31:0] checksum_tmp5 ;

reg  [17:0] checksum_tmp6 ;
reg  [31:0] checksum_tmp7 ;
reg  [31:0] checksum_tmp8 ;
reg  [31:0] checksum_tmp9 ;
reg  [31:0] checksum_tmp10 ;
reg  [16:0] checksum_tmp11 ;
reg  [17:0] checksum_tmp12 ;
reg  [31:0] checksum_tmp13 ;

reg  [31:0] checksum_buf ;
reg  [31:0] checksum_buf_dly ;
wire [15:0] checksum ;

reg  [31:0] checksum_reply_buf ;
reg  [31:0] checksum_reply_buf_dly ;
wire [15:0] reply_checksum ;



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


always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		checksum_tmp0 <= 17'd0 ;
		checksum_tmp1 <= 17'd0 ;
		checksum_tmp2 <= 32'd0 ;
		checksum_tmp3 <= 32'd0 ;
		checksum_tmp4 <= 32'd0 ;
		checksum_tmp5 <= 32'd0 ;

	end
	else if (rcv_state == ICMP_RCV_HEAD  && ip_rx_axis_tvalid)
	begin
		checksum_tmp0 <= 17'd0 ;
		checksum_tmp1 <= 17'd0 ;
		checksum_tmp2 <= 32'd0 ;
		checksum_tmp3 <= 32'd0 ;
		checksum_tmp4 <= 32'd0 ;
		checksum_tmp5 <= 32'd0 ;
	end
	else if (rcv_state == ICMP_RCV_DATA  && ip_rx_axis_tvalid)
	begin
		checksum_tmp0 <= checksum_adder({icmp_type,icmp_code}, icmp_checksum) ;
		checksum_tmp1 <= checksum_adder(icmp_id, icmp_seq) ;
		
		if (ip_rx_axis_tlast)
		begin				
			case(ip_rx_axis_tkeep)
			8'b00000001: 
				  begin		
					checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],8'd0}, checksum_tmp2);		  
				  end
			8'b00000011:
				  begin
					checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp2);		  
				  end
			8'b00000111: 
				 begin
					checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp2);		  
					checksum_tmp3  <= checksum_adder({ip_rx_axis_tdata[23:16],8'd0}, checksum_tmp3);
				  end
			8'b00001111: 
				  begin
					checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp2);		  
					checksum_tmp3  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp3);
				  end
			8'b00011111: 
				  begin
					checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp2);		  
					checksum_tmp3  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp3);
					checksum_tmp4  <= checksum_adder({ip_rx_axis_tdata[39:32],8'd0}, checksum_tmp4);		
				  end
			8'b00111111:
				  begin
					checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp2);		  
					checksum_tmp3  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp3);
					checksum_tmp4  <= checksum_adder({ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]}, checksum_tmp4);
				  end
			8'b01111111:
				  begin
					checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp2);		  
					checksum_tmp3  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp3);
					checksum_tmp4  <= checksum_adder({ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]}, checksum_tmp4);
					checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[55:48],8'd0}, checksum_tmp5);
				
				  end
			8'b11111111:
				  begin
					checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp2);		  
					checksum_tmp3  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp3);
					checksum_tmp4  <= checksum_adder({ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]}, checksum_tmp4);
					checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[55:48],ip_rx_axis_tdata[63:56]}, checksum_tmp5);				
					 end
			endcase	
		end
		else 
		begin
			checksum_tmp2   <= checksum_adder({ip_rx_axis_tdata[7:0],ip_rx_axis_tdata[15:8]}, checksum_tmp2);		  
			checksum_tmp3  <= checksum_adder({ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]}, checksum_tmp3);
			checksum_tmp4  <= checksum_adder({ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]}, checksum_tmp4);
			checksum_tmp5  <= checksum_adder({ip_rx_axis_tdata[55:48],ip_rx_axis_tdata[63:56]}, checksum_tmp5);
		end
	end
  end
  
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
		checksum_tmp6  <= 18'd0 ;
		checksum_tmp7  <= 32'd0 ;
		checksum_tmp8  <= 32'd0 ;
		checksum_tmp9  <= 32'd0 ;
		checksum_tmp10 <= 32'd0 ;
		checksum_tmp11 <= 17'd0 ;
		checksum_tmp12 <= 18'd0 ;
		checksum_tmp13 <= 32'd0 ;
	end
	else if (rcv_state == ICMP_RCV_HEAD  && ip_rx_axis_tvalid)
	begin
		checksum_tmp6  <= 18'd0 ;
		checksum_tmp7  <= 32'd0 ;
		checksum_tmp8  <= 32'd0 ;
		checksum_tmp9  <= 32'd0 ;
		checksum_tmp10 <= 32'd0 ;
		checksum_tmp11 <= 17'd0 ;
		checksum_tmp12 <= 18'd0 ;
		checksum_tmp13 <= 32'd0 ;
	end
	else 
	begin
	
		checksum_tmp6  <= checksum_adder(checksum_tmp0, checksum_tmp1);
		
		checksum_tmp7  <= checksum_adder(checksum_tmp2, checksum_tmp3);	
		checksum_tmp8  <= checksum_adder(checksum_tmp4, checksum_tmp5);		
		checksum_tmp9  <= checksum_adder(checksum_tmp7, checksum_tmp8);
		
		checksum_tmp10  <= checksum_adder(checksum_tmp6, checksum_tmp9);

		checksum_tmp11  <= checksum_adder({ECHO_REPLY,icmp_code}, 16'd0);	
		checksum_tmp12  <= checksum_adder(checksum_tmp11, checksum_tmp1);
		checksum_tmp13  <= checksum_adder(checksum_tmp12, checksum_tmp9);


	end
  end 
  
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
	begin
      checksum_buf <= 32'd0;
	  checksum_buf_dly <= 32'd0;
	  checksum_reply_buf <= 32'd0;
	  checksum_reply_buf_dly <= 32'd0;
	end
    else
	begin
      checksum_buf <= checksum_out(checksum_tmp10) ;
	  checksum_buf_dly <= checksum_out(checksum_buf) ;
	  checksum_reply_buf <= checksum_out(checksum_tmp13) ;
	  checksum_reply_buf_dly <= checksum_out(checksum_reply_buf) ;
	end
  end
 
assign checksum = ~checksum_buf_dly[15:0] ; 		//calculated received checksum
assign reply_checksum = ~checksum_reply_buf_dly[15:0] ; 	//calculated reply checksum


/**************************************************************
Checksum check
**************************************************************/
localparam DlyLength = 6 ;

reg [63:0]       	   	      			icmp_tdata_dly [DlyLength-1:0];
reg [7:0]     	     	      			icmp_tkeep_dly [DlyLength-1:0];
reg [DlyLength-1:0]                     icmp_tvalid_dly ;	
reg [DlyLength-1:0]                     icmp_tlast_dly;
reg [DlyLength-1:0]                     icmp_tusr_dly;


genvar i ;
generate	
	for(i = 0 ;i < DlyLength; i=i+1)
	begin : shifter
		always @(posedge rx_axis_aclk)
		begin
			if (~rx_axis_areset)
			begin
				icmp_tdata_dly[i] 	<= 64'd0 ;
				icmp_tkeep_dly[i] 	<= 8'd0 ;
				icmp_tvalid_dly[i]   <= 1'b0 ;
				icmp_tlast_dly[i]    <= 1'b0 ;	
				icmp_tusr_dly[i]     <= 1'b0 ;					
			end
			else if (icmp_type == ECHO_REQUEST)
			begin
				icmp_tdata_dly[i] <= (i == 0)? icmp_tdata : icmp_tdata_dly[i-1] ;
				icmp_tkeep_dly[i] <= (i == 0)? icmp_tkeep : icmp_tkeep_dly[i-1] ;
				icmp_tvalid_dly[i] <= (i == 0)? icmp_tvalid : icmp_tvalid_dly[i-1] ;
				icmp_tlast_dly[i] <= (i == 0)? icmp_tlast : icmp_tlast_dly[i-1] ;
				
				if (i == 0)
					icmp_tusr_dly[i] <= icmp_tusr ;
				else if (i == DlyLength-1)
				begin
					if (checksum == 16'd0)
						icmp_tusr_dly[i] <= icmp_tusr_dly[i-1] ;
					else
						icmp_tusr_dly[i] <= 1'b0 ;
				end
				else
					icmp_tusr_dly[i] <= icmp_tusr_dly[i-1] ;
				
			end
			else
			begin
				icmp_tdata_dly[i] 	<= 64'd0 ;
				icmp_tkeep_dly[i] 	<= 8'd0 ;
				icmp_tvalid_dly[i]   <= 1'b0 ;
				icmp_tlast_dly[i]    <= 1'b0 ;	
				icmp_tusr_dly[i]     <= 1'b0 ;					
			end
		end
	end
endgenerate

assign icmp_fifo_axis_tdata     =  icmp_tdata_dly[DlyLength-1] ;
assign icmp_fifo_axis_tkeep     =  icmp_tkeep_dly[DlyLength-1] ; 
assign icmp_fifo_axis_tvalid    =  icmp_tvalid_dly[DlyLength-1] ;
assign icmp_fifo_axis_tlast	 	=  icmp_tlast_dly[DlyLength-1] ;	 		
assign icmp_fifo_axis_tusr		 =  icmp_tusr_dly[DlyLength-1] ;	

/**************************************************************
frame storage and send
**************************************************************/
 wire						icmp_fifo_rden ;
 wire [73:0]				icmp_fifo_rdata ; 

/* icmp tx stream fifo */
 std_fwft_fifo 
#(
  .WIDTH(74) ,
  .DEPTH(8),
  .FIFO_TYPE("fwft")
)
icmp_data_fifo
(
  .clk       (rx_axis_aclk   ),
  .rst_n     (rx_axis_areset ),
  .wren      (icmp_fifo_axis_tvalid),
  .rden      (icmp_fifo_rden ),
  .data      ({icmp_fifo_axis_tdata,icmp_fifo_axis_tkeep,1'b1,icmp_fifo_axis_tlast}),
  .q         (icmp_fifo_rdata),
  .full      (  ),
  .empty     (empty  )
) ;

/* icmp ready signal */
always @(posedge rx_axis_aclk)
  begin
    if (~rx_axis_areset)
		icmp_not_empty <= 1'b0 ;
	else if (rcv_state == ICMP_GOOD_FRAME_HEAD)
		icmp_not_empty <= 1'b1 ;
	else
		icmp_not_empty <= 1'b0 ;
  end

assign icmp_fifo_rden = (rcv_state == ICMP_GOOD_FRAME)?(icmp_tx_axis_tready & ~empty) : (rcv_state == ICMP_BAD_FRAME)? (~empty) : 1'b0 ;

  
always @(*)
  begin
	if (rcv_state == ICMP_GOOD_FRAME_HEAD)
    begin

		icmp_tx_axis_tdata <= {icmp_seq[7:0],icmp_seq[15:8],icmp_id[7:0],icmp_id[15:8],
							reply_checksum[7:0],reply_checksum[15:8],icmp_code,ECHO_REPLY};
		icmp_tx_axis_tkeep <= 8'hff ;
		icmp_tx_axis_tvalid <= 1'b1 ;
		icmp_tx_axis_tlast <= 1'b0 ;
	end
	else if (rcv_state == ICMP_GOOD_FRAME)
	begin
		icmp_tx_axis_tdata <= icmp_fifo_rdata[73:10];
		icmp_tx_axis_tkeep <= icmp_fifo_rdata[9:2] ;
		icmp_tx_axis_tvalid <= icmp_fifo_rdata[1] ; 
		icmp_tx_axis_tlast <= icmp_fifo_rdata[0];
	end
	else
	begin
      icmp_tx_axis_tdata <= 64'd0;
	  icmp_tx_axis_tkeep <= 8'd0 ;
	  icmp_tx_axis_tvalid <= 1'b0 ;
	  icmp_tx_axis_tlast <= 1'b0 ;
	end
  end	   

	
endmodule



// IP Decryptor end

