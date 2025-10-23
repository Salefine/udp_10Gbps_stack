/****************************************************************************
 * @file    us_icmp_reply.v
 * @brief  
 * @author  weslie (zzhi4832@gmail.com)
 * @version 1.0
 * @date    2025-01-22
 * 
 * @par :
 * ___________________________________________________________________________
 * |    Date       |  Version    |       Author     |       Description      |
 * |---------------|-------------|------------------|------------------------|
 * |               |   v1.0      |    weslie        |                        |
 * |---------------|-------------|------------------|------------------------|
 * 
 * @copyright Copyright (c) 2025 welie
 * ***************************************************************************/


/******************************************************************************
ex:
host ---> FPGA send an icmp data packet
{16'h0100, 16'h7c4d, 16'hed18, 16'h0008 }
{16'h6867, 16'h6665, 16'h6463, 16'h6261 }
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Type = 8    |   Code = 0    |        Checksum = 0x18ed      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Identifier = 0x4d7c     |    Sequence Number = 0x0001  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           Data (8 bytes)                      |
|                   0x61 0x62 0x63 0x64                         |
|                   0x65 0x66 0x67 0x68                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

FPGA ---> host icmp data packet
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Type = 0    |   Code = 0    |        Checksum = 0x20ed      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Identifier = 0x4d7c     |    Sequence Number = 0x0001  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           Data (8 bytes)                      |
|                   0x61 0x62 0x63 0x64                         |
|                   0x65 0x66 0x67 0x68                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

*******************************************************************************/


module us_icmp_reply(
    	input                           rx_axis_aclk,
		input                           rx_axis_aresetn,
		/* ip rx axis interface */
		input [63:0]       	     		ip_rx_axis_tdata,
        input [7:0]     	     		ip_rx_axis_tkeep,
        input                           ip_rx_axis_tvalid,		 
        input                           ip_rx_axis_tlast,
        input                          	ip_rx_axis_tuser,
		/* udp rx axis interface */
		output reg [63:0]       	   	icmp_tx_axis_tdata,
        output reg [7:0]     	     	icmp_tx_axis_tkeep,
        output reg                      icmp_tx_axis_tvalid,		 
        output reg                      icmp_tx_axis_tlast,
        input  wire                     icmp_tx_axis_tready,

        output reg                      icmp_not_empty 
);


localparam      ECHO_REQUEST    =   8'h8;
localparam      ECHO_REPLY      =   8'h0;

//signals for fifo write and read
reg     [3:0]   checksum_count  =   0;

reg [15:0]  checksum_payload0;
reg [15:0]  checksum_payload1;
reg [15:0]  checksum_payload2;
reg [15:0]  checksum_payload3;
reg [15:0]  checksum_header;
reg [15:0]  checksum_header_reply;
reg [15:0]  checksum_payload_d0;
reg [15:0]  checksum_payload_d1;
reg [15:0]  checksum_payload;
reg [15:0]  checksum;

reg         icmp_payload_wren   =   0;
reg         icmp_payload_rden   =   0;
//wire        icmp_payload_full       ;
wire        icmp_payload_empty      ;
//wire        icmp_payload_almost_full;
wire[73:0]  icmp_payload_dout       ;

reg     [7:0]   rq_icmp_type       =   0;
reg     [7:0]   rq_icmp_code       =   0;
reg     [15:0]  rq_icmp_checksum   =   0;
reg     [15:0]  rq_icmp_identify   =   0;
reg     [15:0]  rq_icmp_sequence   =   0;

reg     [7:0]   cc_icmp_type       =   0;
reg     [7:0]   cc_icmp_code       =   0;
reg     [15:0]  cc_icmp_checksum   =   0;
reg     [15:0]  cc_icmp_identify   =   0;
reg     [15:0]  cc_icmp_sequence   =   0;
/*********************************************************************
 * 1. state machine for receiving icmp data packet
 *********************************************************************/

localparam  RECV_HEADER     =   7'b0000001;
localparam  RECV_DATA       =   7'b0000010;
localparam  RECV_GOOD       =   7'b0000100;
localparam  RECV_FAIL       =   7'b0001000;
localparam  SEND_HEADER     =   7'b0010000;
localparam  SEND_DATA       =   7'b0100000;
localparam  FRAME_BAD       =   7'b1000000;

reg    [6:0]    icmp_recv_state     =   0;
reg    [6:0]    icmp_recv_next_state=   0;

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        icmp_recv_state <= RECV_HEADER;
    end
    else begin
        icmp_recv_state <= icmp_recv_next_state;
    end
end

always @(*) begin
    case (icmp_recv_state)
        RECV_HEADER: begin
            if (ip_rx_axis_tvalid & (~ip_rx_axis_tlast)) begin
                icmp_recv_next_state = RECV_DATA;
            end
            else begin
                icmp_recv_next_state = RECV_HEADER;
            end
        end

        RECV_DATA : begin
            if (rq_icmp_type == ECHO_REQUEST) begin
                if (ip_rx_axis_tvalid & ip_rx_axis_tlast & (~ip_rx_axis_tuser)) begin
                    icmp_recv_next_state = RECV_GOOD;
                end
                else if (ip_rx_axis_tvalid & ip_rx_axis_tlast & (ip_rx_axis_tuser)) begin
                    icmp_recv_next_state = RECV_FAIL;
                end
                else begin
                    icmp_recv_next_state = RECV_DATA;
                end                
            end
            else begin
                if (ip_rx_axis_tvalid & ip_rx_axis_tlast) begin
                    icmp_recv_next_state = RECV_HEADER;
                end
                else begin
                    icmp_recv_next_state = RECV_DATA;
                end                   
            end   
        end

        RECV_GOOD : begin
           if ((checksum_count == 3) && checksum == 16'h0) begin
                icmp_recv_next_state = SEND_HEADER; 
           end
           else if ((checksum_count == 3) && checksum != 16'h0) begin
                icmp_recv_next_state = FRAME_BAD;
           end
           else begin
                icmp_recv_next_state = RECV_GOOD;
           end
        end

        RECV_FAIL : begin
            icmp_recv_next_state = FRAME_BAD;
        end

        SEND_HEADER : begin
            if (icmp_tx_axis_tvalid & icmp_tx_axis_tready) begin
                icmp_recv_next_state = SEND_DATA;
            end
            else begin
                icmp_recv_next_state = SEND_HEADER;
            end
        end

        SEND_DATA : begin
            if (icmp_tx_axis_tvalid & icmp_tx_axis_tready & icmp_tx_axis_tlast) begin
                icmp_recv_next_state = RECV_HEADER;
            end
            else begin
                icmp_recv_next_state = SEND_DATA;
            end            
        end

        FRAME_BAD : begin
            if (icmp_payload_empty) begin
                icmp_recv_next_state = RECV_HEADER;
            end
            else begin
                icmp_recv_next_state = FRAME_BAD;
            end
        end
        default: begin
            icmp_recv_next_state = RECV_HEADER;
        end
    endcase
end

/*********************************************************************
 * 2. calcute icmp data packet's checksum
 *********************************************************************/
 function    [15:0]  checksum_gen
  (
    input       [15:0]  dataina,
    input       [15:0]  datainb
  );
  
    reg [16:0]  sum ;

  begin
    sum = dataina[15:0] + datainb[15:0];
    checksum_gen = sum[16] ? sum[15:0] + 1 : sum[15:0];
  end
  
endfunction

function    [15:0]  checksum_plus
  (
    input       [15:0]  dataina,
    input       [15:0]  datainb,
    input       [15:0]  datainc,
    input       [15:0]  dataind
  );
  
  reg [15:0]  sum0;
  reg [15:0]  sum1;

  begin
    sum0 = checksum_gen(dataina , datainb);
    sum1 = checksum_gen(sum0    , datainc);
    checksum_plus = checksum_gen(sum1    , dataind);
  end
  
endfunction


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        checksum_header  <= 0;
        checksum_header_reply <= 0;
    end
    else if ((icmp_recv_state == RECV_HEADER) & (ip_rx_axis_tvalid)) begin
        checksum_header  <= checksum_plus({ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]},
                                          {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]},
                                          {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]},
                                          {ip_rx_axis_tdata[55:48], ip_rx_axis_tdata[63:56]});
        checksum_header_reply <= checksum_plus(
            {ECHO_REPLY,8'h0},
            16'h0000,
            {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]},
            {ip_rx_axis_tdata[55:48], ip_rx_axis_tdata[63:56]}
        );                              
    end
    else begin
        checksum_header <= checksum_header;
        checksum_header_reply <= checksum_header_reply;
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        checksum_payload0 <= 0;
        checksum_payload1 <= 0;
        checksum_payload2 <= 0;
        checksum_payload3 <= 0;
    end
    else if (icmp_recv_state == RECV_DATA & (~ip_rx_axis_tlast)) begin
        checksum_payload0 <= checksum_gen({ip_rx_axis_tdata[7:0]   ,  ip_rx_axis_tdata[15:8] },
                                           checksum_payload0);
        checksum_payload1 <= checksum_gen({ip_rx_axis_tdata[23:16] ,  ip_rx_axis_tdata[31:24]},
                                           checksum_payload1);
        checksum_payload2 <= checksum_gen({ip_rx_axis_tdata[39:32] ,  ip_rx_axis_tdata[47:40]},
                                           checksum_payload2);
        checksum_payload3 <= checksum_gen({ip_rx_axis_tdata[55:48] ,  ip_rx_axis_tdata[63:56]},
                                           checksum_payload3); 
                                                                                                                                                                                                                                         
    end
    else if (icmp_recv_state == RECV_DATA & (ip_rx_axis_tlast)) begin
        case (ip_rx_axis_tkeep)
            8'b00000001: begin
                checksum_payload0 <= checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0], 8'h0});
            end
            8'b00000011: begin
                checksum_payload0 <= checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0], ip_rx_axis_tdata[15:8]});

            end
            8'b00000111: begin
                checksum_payload0 <= checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1 <= checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], 8'h0                  });

            end
            8'b00001111: begin
                checksum_payload0 <= checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1 <= checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});                            
            end     
            8'b00011111: begin
                checksum_payload0 <= checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1 <= checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});  
                checksum_payload2 <= checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], 8'h0});                  
            end
            8'b00111111: begin
                checksum_payload0 <= checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1 <= checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});  
                checksum_payload2 <= checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]});               
            end
            8'b01111111: begin
                checksum_payload0 <= checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1 <= checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});  
                checksum_payload2 <= checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]}); 
                checksum_payload3 <= checksum_gen(checksum_payload3, {ip_rx_axis_tdata[55:48], 8'h0});       
                           
            end
            8'b11111111: begin
                checksum_payload0 <= checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1 <= checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});  
                checksum_payload2 <= checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]}); 
                checksum_payload3 <= checksum_gen(checksum_payload3, {ip_rx_axis_tdata[55:48], ip_rx_axis_tdata[63:56]});        
                        
            end                                             
            default: begin
                checksum_payload0 <= checksum_payload0;
                checksum_payload1 <= checksum_payload1;
                checksum_payload2 <= checksum_payload2;
                checksum_payload3 <= checksum_payload3;                
            end
        endcase
    end
    else if(icmp_recv_state == SEND_HEADER || icmp_recv_state == FRAME_BAD)begin
        checksum_payload0 <= 0;
        checksum_payload1 <= 0;
        checksum_payload2 <= 0;
        checksum_payload3 <= 0;

    end
    else begin
        checksum_payload0 <= checksum_payload0;
        checksum_payload1 <= checksum_payload1;
        checksum_payload2 <= checksum_payload2;
        checksum_payload3 <= checksum_payload3;
    end
end



always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        checksum_payload_d0 <= 0;
        checksum_payload_d1 <= 0;
        checksum_payload    <= 0;
        checksum            <= 0;
        checksum_count      <= 0;
    end
    else if (icmp_recv_state == RECV_GOOD) begin
        checksum_payload_d0 <= checksum_gen(checksum_payload0,checksum_payload1);
        checksum_payload_d1 <= checksum_gen(checksum_payload2,checksum_payload3);
        checksum_payload    <= checksum_gen(checksum_payload_d0,checksum_payload_d1);
        checksum            <= ~checksum_gen(checksum_payload, checksum_header);
        checksum_count      <= checksum_count + 1;
    end
    else begin
        checksum_payload_d0 <= 0;
        checksum_payload_d1 <= 0;
        checksum_payload    <= 0;
        checksum            <= 0;
        checksum_count      <= 0;        
    end
end



/*********************************************************************
 * 3. receive icmp data
 *********************************************************************/

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        rq_icmp_type <= 0;
        rq_icmp_code <= 0;
        rq_icmp_checksum <= 0;
        rq_icmp_identify <= 0;
        rq_icmp_sequence <= 0;
    end
    else if (icmp_recv_state == RECV_HEADER & (icmp_recv_next_state != icmp_recv_state)) begin
        rq_icmp_type <= ip_rx_axis_tdata[7:0];
        rq_icmp_code <= ip_rx_axis_tdata[15:8];
        rq_icmp_checksum <= {ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]};
        rq_icmp_identify <= {ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]};
        rq_icmp_sequence <= {ip_rx_axis_tdata[55:48],ip_rx_axis_tdata[63:56]};
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        cc_icmp_type     <= 0;
        cc_icmp_code     <= 0;
        cc_icmp_checksum <= 0;
        cc_icmp_identify <= 0;
        cc_icmp_sequence <= 0;
    end
    else if (icmp_recv_state == RECV_GOOD &(checksum_count == 3)) begin
        cc_icmp_type     <= 0;
        cc_icmp_code     <= rq_icmp_code;
        cc_icmp_checksum <= ~checksum_gen(checksum_payload , checksum_header_reply) ;
        cc_icmp_identify <= rq_icmp_identify;
        cc_icmp_sequence <= rq_icmp_sequence;        
    end
end

/*********************************************************************
 * 4. write icmp data to fifo
 *********************************************************************/
localparam DLY_LENGTH = 1;

reg     [63:0]  icmp_packet_fifo_tdata [0 : DLY_LENGTH-1];
reg     [7:0]   icmp_packet_fifo_tkeep [0 : DLY_LENGTH-1];
reg             icmp_packet_fifo_tvalid[0 : DLY_LENGTH-1];
reg             icmp_packet_fifo_tlast [0 : DLY_LENGTH-1];


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        icmp_payload_wren <= 0;
    end
    else if(icmp_recv_state == RECV_DATA && (rq_icmp_type == ECHO_REQUEST))begin
        icmp_payload_wren <= 1;
    end
    else begin
        icmp_payload_wren <= 0;
    end
end

genvar i;
generate
    for (i = 0; i < DLY_LENGTH ; i = i + 1) begin:delay_line
        always @(posedge rx_axis_aclk) begin
            if (~rx_axis_aresetn) begin
                icmp_packet_fifo_tdata[i]  <=  0;
                icmp_packet_fifo_tkeep[i]  <=  0;
                icmp_packet_fifo_tvalid[i] <=  0;
                icmp_packet_fifo_tlast[i]  <=  0;
            end
            else if (rq_icmp_type == ECHO_REQUEST) begin
                icmp_packet_fifo_tdata[i]  <=  (i == 0) ? ip_rx_axis_tdata : icmp_packet_fifo_tdata[i-1];
                icmp_packet_fifo_tkeep[i]  <=  (i == 0) ? ip_rx_axis_tkeep : icmp_packet_fifo_tkeep[i-1];
                icmp_packet_fifo_tvalid[i] <=  (i == 0) ? ip_rx_axis_tvalid : icmp_packet_fifo_tvalid[i-1];
                icmp_packet_fifo_tlast[i]  <=  (i == 0) ? ip_rx_axis_tlast : icmp_packet_fifo_tlast[i-1];                
            end
            else begin
                icmp_packet_fifo_tdata[i]  <=  0;
                icmp_packet_fifo_tkeep[i]  <=  0;
                icmp_packet_fifo_tvalid[i] <=  0;
                icmp_packet_fifo_tlast[i]  <=  0;                
            end
        end
    end
endgenerate



xpm_sync_fifo #(
    .WIDTH     	(74     ),
    .DEPTH     	(11     ),
    .FIFO_TYPE 	("fwft"  )
    )
icmp_payload(
    .clk         	(rx_axis_aclk           ),
    .rst_n       	(rx_axis_aresetn        ),
    .wr_en       	(icmp_payload_wren      ),
    .rd_en       	(icmp_payload_rden      ),
    .data        	({icmp_packet_fifo_tdata[DLY_LENGTH-1],
                             icmp_packet_fifo_tkeep[DLY_LENGTH-1],
                             icmp_packet_fifo_tlast[DLY_LENGTH-1],
                             icmp_packet_fifo_tvalid[DLY_LENGTH-1]}),
    .dout        	(icmp_payload_dout      ),
    .full        	(                       ),
    .empty       	(icmp_payload_empty     ),
    .almost_full 	(                       )
);

always @(*) begin
    if(icmp_recv_state == SEND_HEADER)begin
        icmp_not_empty <= 1;
    end
    else begin
        icmp_not_empty <= 0;
    end
end

/*********************************************************************
 * 5. build icmp reply data's packet
 *********************************************************************/

always @(*) begin
    if (~rx_axis_aresetn) begin
        icmp_payload_rden <= 0;
    end
    else begin
        icmp_payload_rden <= (icmp_recv_state == SEND_DATA) ? (icmp_tx_axis_tready & (~icmp_payload_empty)) : 
                                                              (icmp_recv_state == FRAME_BAD) ? (~icmp_payload_empty): 0;
    end
end

always @(*) begin
    if (icmp_recv_state == SEND_HEADER) begin
        icmp_tx_axis_tdata  <= {
            cc_icmp_sequence[7:0], cc_icmp_sequence[15:8],
            cc_icmp_identify[7:0], cc_icmp_identify[15:8],
            cc_icmp_checksum[7:0], cc_icmp_checksum[15:8],
            cc_icmp_code         , cc_icmp_type
        };
        icmp_tx_axis_tkeep  <= 8'hff;
        icmp_tx_axis_tlast  <= 0;
        icmp_tx_axis_tvalid <= 1;
    end
    else if (icmp_recv_state == SEND_DATA) begin
        icmp_tx_axis_tdata <= icmp_payload_dout[73:10];
        icmp_tx_axis_tkeep <= icmp_payload_dout[9:2];
        icmp_tx_axis_tlast <= icmp_payload_dout[1];
        icmp_tx_axis_tvalid<= icmp_payload_dout[0];
    end
    else begin
        icmp_tx_axis_tdata  <=  0;
        icmp_tx_axis_tkeep  <=  0;
        icmp_tx_axis_tlast  <=  0;
        icmp_tx_axis_tvalid <=  0;        
    end
end


endmodule


