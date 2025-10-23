/****************************************************************************
 * @file    us_udp_rx.v
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

module us_udp_rx#(
    parameter FPGA_TYPE = "usplus" // in this mode, if ip_rx_axis_tusr is high, indicate this packet is a bad packet
) (
    	input                           rx_axis_aclk,
		input                           rx_axis_aresetn,
		/* ip rx axis interface */
		input [63:0]       	     		ip_rx_axis_tdata,
        input [7:0]     	     		ip_rx_axis_tkeep,
        input                           ip_rx_axis_tvalid,		 
        input                           ip_rx_axis_tlast,
        input                          	ip_rx_axis_tuser,
		/* udp rx axis interface */
		output reg [63:0]       	   	udp_rx_axis_tdata,
        output reg [7:0]     	     	udp_rx_axis_tkeep,
        output reg                      udp_rx_axis_tvalid,		 
        output reg                      udp_rx_axis_tlast,
        output reg                      udp_rx_axis_tuser,
		
		input [31:0]					recv_dst_ip_addr,	//received destination ip address, for checksum use
		input [31:0]					recv_src_ip_addr    //received source ip address, for checksum use
);


/****************************************************************************
 * state machine for udp data receive
 ***************************************************************************/
localparam [3:0]    UDP_RECV_HEADER  = 4'b0001;
localparam [3:0]    UDP_RECV_PAYLOAD = 4'b0010;
localparam [3:0]    UDP_RECV_SUCCESS = 4'b0100;
localparam [3:0]    UDP_RECV_FAILED  = 4'b1000;

reg        [3:0]    recv_state       =   4'b0;
reg        [3:0]    recv_next_state  =   4'b0;

reg        [1:0]    recv_status      =  0;
/****************************************************************************
 * udp tx state machine
 ***************************************************************************/
localparam [3:0]    UDP_SEND_IDLE     = 4'b0001;
localparam [3:0]    UDP_SEND_PAYLOAD  = 4'b0010;


reg        [3:0]    udp_send_state        = 4'b0000;
reg        [3:0]    udp_send_next_state   = 4'b0000;

/****************************************************************************
 * register define for checksum
 ***************************************************************************/
reg [15:0]         checksum_payload0; //
reg [15:0]         checksum_payload1; //
reg [15:0]         checksum_payload2; //
reg [15:0]         checksum_payload3; //
reg [15:0]         checksum_payload4; 
reg [15:0]         checksum_payload5; 
reg [15:0]         checksum_payload; 

reg [15:0]         checksum_udp_packet; 

reg [15:0]         checksum_header0;
reg [15:0]         checksum_header1;
reg [15:0]         checksum_header2;
reg [15:0]         checksum_header3;
reg [15:0]         checksum_header4;
reg [15:0]         checksum_header5;
reg [15:0]         checksum_header6;
reg [15:0]         checksum_header7;
reg [15:0]         checksum_header ;
// reg [15:0]         checksum_header9;


/****************************************************************************
 * receive header information
 ***************************************************************************/

reg        [15:0]   recv_dst_port    = 0;
reg        [15:0]   recv_src_port    = 0;
reg        [15:0]   recv_length      = 0;
reg        [15:0]   recv_checksum    = 0;

reg         udp_data_fifo_wren  =   0;
reg         udp_data_fifo_rden  =   0;
reg [74:0]  udp_data_fifo_data  =   0;
wire[74:0]  udp_data_fifo_dout  ;
//wire        udp_data_fifo_empty;

wire        udp_length_fifo_wren  ;
reg         udp_length_fifo_rden  =   0;
wire[32:0]  udp_length_fifo_data  ;
wire[32:0]  udp_length_fifo_dout  ;
wire        udp_length_fifo_empty ;

reg [15:0]  udp_packet_length   =   0;
reg [15:0]  tmp_packet_len      =   0;

reg     [63:0]  udp_tdata_reg   =   0;
reg     [7:0]   udp_tkeep_reg   =   0;
reg             udp_tvalid_reg  =   0;
reg             udp_tlast_reg   =   0;
reg             udp_tuser_reg   =   0; 

localparam DLY_LENGTH = 4;

reg     [63:0]  udp_tdata_dly[0:DLY_LENGTH - 1];
reg     [7:0]   udp_tkeep_dly[0:DLY_LENGTH - 1];
reg     [DLY_LENGTH - 1 : 0]  udp_tvalid_dly;
reg     [DLY_LENGTH - 1 : 0]  udp_tlast_dly;
reg     [DLY_LENGTH - 1 : 0]  udp_tuser_dly;

wire    [15:0]  udp_packetlen     ;
wire    [15:0]  udp_recv_len      ;
reg     [15:0]  trans_cnt   =   0 ;
wire            tuser             ;
/******************************parameter end********************************/



/****************************************************************************
 * function declare
 ***************************************************************************/
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

/****************************************************************************
 * udp receive state machine
 ***************************************************************************/

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_state          <=  UDP_RECV_HEADER;
    end
    else begin
        recv_state          <=  recv_next_state;
    end
end

always @(*) begin
    case (recv_state)
        UDP_RECV_HEADER  : begin
            if (ip_rx_axis_tvalid & (~ip_rx_axis_tlast)) begin
                recv_next_state     <=  UDP_RECV_PAYLOAD;
            end
            else begin
                recv_next_state     <=  UDP_RECV_HEADER;
            end
        end
        UDP_RECV_PAYLOAD : begin
            if(ip_rx_axis_tvalid & ip_rx_axis_tlast)begin
                if (ip_rx_axis_tuser) begin
                    recv_next_state      <= UDP_RECV_FAILED;
                end
                else begin
                    recv_next_state      <= UDP_RECV_SUCCESS;
                end   
            end
            else begin
                recv_next_state     <= UDP_RECV_PAYLOAD;
            end
        end
        UDP_RECV_SUCCESS : begin
            recv_next_state         <=  UDP_RECV_HEADER;
        end
        UDP_RECV_FAILED  : begin
            recv_next_state         <=  UDP_RECV_HEADER;
        end
        default: begin
            recv_next_state         <=  UDP_RECV_HEADER;
        end
    endcase
end


/****************************************************************************
 * 1. receive udp header information and calcute checksum
   0      7 8     15 16    23 24    31
 +--------+--------+--------+--------+
 |          Source IP Address        |
 +--------+--------+--------+--------+
 |       Destination IP Address      |
 +--------+--------+--------+--------+
 |  Zero  |Protocol|     UDP Length  |
 +--------+--------+--------+--------+
  0      7 8     15 16    23 24    31
 +--------+--------+--------+--------+
 |     Source Port | Destination Por |
 +--------+--------+--------+--------+
 |     Length      |  Checksum       |
 +--------+--------+--------+--------+

 ***************************************************************************/
always @(posedge rx_axis_aclk) begin
    if(~rx_axis_aresetn)begin
        recv_dst_port <= 0;
        recv_src_port <= 0;
        recv_length   <= 0;
        recv_checksum <= 0; 
    end
    else if (recv_state == UDP_RECV_HEADER & (recv_state != recv_next_state)) begin
        recv_dst_port <= {ip_rx_axis_tdata[23:16],ip_rx_axis_tdata[31:24]};
        recv_src_port <= {ip_rx_axis_tdata[7:0]  ,ip_rx_axis_tdata[15:8] };
        recv_length   <= {ip_rx_axis_tdata[39:32],ip_rx_axis_tdata[47:40]};
        recv_checksum <= {ip_rx_axis_tdata[55:48],ip_rx_axis_tdata[63:56]};
    end
    else begin
        recv_dst_port <= recv_dst_port;
        recv_src_port <= recv_src_port;
        recv_length   <= recv_length;
        recv_checksum <= recv_checksum;        
    end
end


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        checksum_header0    <= 0;
        checksum_header1    <= 0;
        checksum_header2    <= 0;
        checksum_header3    <= 0;
        checksum_header4    <= 0;

    end
    else if (recv_state == UDP_RECV_PAYLOAD & ip_rx_axis_tvalid) begin
        checksum_header0    <=  checksum_gen(recv_src_ip_addr[15:0] , recv_src_ip_addr[31:16]);
        checksum_header1    <=  checksum_gen(recv_dst_ip_addr[31:16], recv_dst_ip_addr[15:0] );
        checksum_header2    <=  checksum_gen(8'h11                  , recv_length            );
        checksum_header3    <=  checksum_gen(recv_src_port          , recv_dst_port          );
        checksum_header4    <=  checksum_gen(recv_checksum          , recv_length            );

    end
    else if(recv_state == UDP_RECV_HEADER & ip_rx_axis_tvalid)begin
        checksum_header0    <= 0;
        checksum_header1    <= 0;
        checksum_header2    <= 0;
        checksum_header3    <= 0;
        checksum_header4    <= 0;       
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        checksum_payload0   <=  0;
        checksum_payload1   <=  0;
        checksum_payload2   <=  0;
        checksum_payload3   <=  0;
    end
    else if(recv_state == UDP_RECV_PAYLOAD & ip_rx_axis_tvalid & (~ip_rx_axis_tlast))begin
        checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
        checksum_payload1   <=  checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});
        checksum_payload2   <=  checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]});
        checksum_payload3   <=  checksum_gen(checksum_payload3, {ip_rx_axis_tdata[55:48], ip_rx_axis_tdata[63:56]});
    end
    else if (recv_state == UDP_RECV_PAYLOAD & ip_rx_axis_tvalid & (ip_rx_axis_tlast)) begin
        case (ip_rx_axis_tkeep)
            8'b00000001: begin
                checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , 8'h0});
            end
            8'b00000011: begin
                checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
            end
            8'b00000111: begin
                checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1   <=  checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], 8'h00});
            end
            8'b00001111: begin
                checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1   <=  checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});
            end
            8'b00011111: begin
                checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1   <=  checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});
                checksum_payload2   <=  checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], 8'h00});
            end
            8'b00111111: begin
                checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1   <=  checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});
                checksum_payload2   <=  checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]});
            end
            8'b01111111: begin
                checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1   <=  checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});
                checksum_payload2   <=  checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]});
                checksum_payload3   <=  checksum_gen(checksum_payload3, {ip_rx_axis_tdata[55:48], 8'h00});
            end
            8'b11111111: begin
                checksum_payload0   <=  checksum_gen(checksum_payload0, {ip_rx_axis_tdata[7:0]  , ip_rx_axis_tdata[15:8]});
                checksum_payload1   <=  checksum_gen(checksum_payload1, {ip_rx_axis_tdata[23:16], ip_rx_axis_tdata[31:24]});
                checksum_payload2   <=  checksum_gen(checksum_payload2, {ip_rx_axis_tdata[39:32], ip_rx_axis_tdata[47:40]});
                checksum_payload3   <=  checksum_gen(checksum_payload3, {ip_rx_axis_tdata[55:48], ip_rx_axis_tdata[63:56]});
            end            
            default: begin
                // checksum_payload0   <=  0;
                // checksum_payload1   <=  0;
                // checksum_payload2   <=  0;
                // checksum_payload3   <=  0;               
            end
        endcase
    end
    else if(recv_state == UDP_RECV_HEADER & ip_rx_axis_tvalid)begin
        checksum_payload0   <=  0;
        checksum_payload1   <=  0;
        checksum_payload2   <=  0;
        checksum_payload3   <=  0;        
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        checksum_header5    <= 0;
        checksum_header6    <= 0;
        checksum_header7    <= 0;
        checksum_header     <= 0;
        checksum_payload4   <= 0;
        checksum_payload5   <= 0;   
        checksum_payload    <= 0; 
        checksum_udp_packet <= 0;      
    end 
    else if(recv_state == UDP_RECV_HEADER & ip_rx_axis_tvalid)begin
        checksum_header5    <= 0;
        checksum_header6    <= 0;
        checksum_header7    <= 0;
        checksum_header     <= 0;
        checksum_payload4   <= 0;
        checksum_payload5   <= 0;   
        checksum_payload    <= 0; 
        checksum_udp_packet <= 0;           
    end
    else begin
        checksum_header5    <=  checksum_gen(checksum_header0       , checksum_header1);
        checksum_header6    <=  checksum_gen(checksum_header3       , checksum_header2);
        checksum_header7    <=  checksum_gen(checksum_header5       , checksum_header4);
        checksum_header     <=  checksum_gen(checksum_header6       , checksum_header7);
//        checksum_header     <=  checksum_gen(checksum_header4  , checksum_plus(checksum_header0,
//                                checksum_header1, checksum_header2,checksum_header3));
        checksum_payload4   <=  checksum_gen(checksum_payload0      , checksum_payload1);
        checksum_payload5   <=  checksum_gen(checksum_payload2      , checksum_payload3);
        checksum_payload    <=  checksum_gen(checksum_payload4      , checksum_payload5);
//        checksum_payload    <= checksum_plus(checksum_payload0      , checksum_payload1,
//                                             checksum_payload2      , checksum_payload3);
        checksum_udp_packet <=  ~checksum_gen(checksum_header       , checksum_payload );
    end
end


/****************************************************************************
 * delay all input data 8 clock period for calcute udp's header checksum
 ***************************************************************************/


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        udp_tdata_reg   <= 0;
        udp_tkeep_reg   <= 0;
        udp_tvalid_reg  <= 0;
        udp_tlast_reg   <= 0;
        udp_tuser_reg   <= 0;
    end
    else if (recv_state == UDP_RECV_PAYLOAD & ip_rx_axis_tvalid) begin
        udp_tdata_reg   <= ip_rx_axis_tdata;
        udp_tkeep_reg   <= ip_rx_axis_tkeep;
        udp_tvalid_reg  <= ip_rx_axis_tvalid;
        udp_tlast_reg   <= ip_rx_axis_tlast;
        udp_tuser_reg   <= ip_rx_axis_tuser;
    end
    else begin
        udp_tdata_reg   <= 0;
        udp_tkeep_reg   <= 0;
        udp_tvalid_reg  <= 0;
        udp_tlast_reg   <= 0;
        udp_tuser_reg   <= 0;        
    end
end


genvar i;
generate
    for (i = 0; i < DLY_LENGTH ; i = i + 1) begin:delay_line
        always @(posedge rx_axis_aclk) begin
            if (~rx_axis_aresetn) begin
                udp_tdata_dly[i]    <=  0;
                udp_tkeep_dly[i]    <=  0;
                udp_tvalid_dly[i]   <=  0;
                udp_tlast_dly[i]    <=  0;
                udp_tuser_dly[i]    <=  0;
            end
            else begin
                udp_tdata_dly[i]    <=  (i == 0) ? udp_tdata_reg : udp_tdata_dly[i-1];
                udp_tkeep_dly[i]    <=  (i == 0) ? udp_tkeep_reg : udp_tkeep_dly[i-1];
                udp_tvalid_dly[i]   <=  (i == 0) ? udp_tvalid_reg : udp_tvalid_dly[i-1];
                udp_tlast_dly[i]    <=  (i == 0) ? udp_tlast_reg : udp_tlast_dly[i-1];
                if(i == 0)begin
                    udp_tuser_dly[i] <= udp_tuser_reg;
                end
                else if(i == DLY_LENGTH - 1)begin
                    if(checksum_udp_packet == 16'h0000)begin
                            udp_tuser_dly[i] <= udp_tuser_dly[i-1];
                        end
                    else begin 
                        if(udp_tlast_dly[DLY_LENGTH-2])begin
                            udp_tuser_dly[i] <= 1;
                        end  
                        else begin
                            udp_tuser_dly[i] <= 0;
                        end
                    end
                end
                else begin
                    udp_tuser_dly[i] <= udp_tuser_dly[i-1];
                end      
            end
        end
    end
endgenerate

/* **************************************************************************
 * udp's delay data write to fifo 
 ***************************************************************************/


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        udp_packet_length   <=  0;
        tmp_packet_len      <=  0;
    end
    else if(udp_tvalid_reg)begin
        if(~udp_tlast_reg)begin
            tmp_packet_len      <=  tmp_packet_len + 1;
        end
        else begin
            udp_packet_length   <=  tmp_packet_len + 1;
            tmp_packet_len      <=  0;
        end
    end
    else begin
        
    end
end

assign udp_length_fifo_data = {udp_packet_length , recv_length, udp_tuser_dly[DLY_LENGTH - 1]};
assign udp_length_fifo_wren = (udp_tvalid_dly[DLY_LENGTH-1] & udp_tlast_dly[DLY_LENGTH-1]);

xpm_sync_fifo #(
    .WIDTH     	(33     ),
    .DEPTH     	(8     ),
    .FIFO_TYPE 	("fwft"))
udp_length_fifo(
    .clk         	(rx_axis_aclk          ),
    .rst_n       	(rx_axis_aresetn        ),
    .wr_en       	(udp_length_fifo_wren        ),
    .rd_en       	(udp_length_fifo_rden        ),
    .data        	(udp_length_fifo_data        ),
    .dout        	(udp_length_fifo_dout        ),
    .full        	(         ),
    .empty       	(udp_length_fifo_empty        ),
    .almost_full 	(  )
);


always @(*) begin
    udp_data_fifo_wren = udp_tvalid_dly[DLY_LENGTH - 1] ? 1 : 0;
end

always @(*) begin
    udp_data_fifo_data = {udp_tdata_dly[DLY_LENGTH - 1], 
                          udp_tkeep_dly[DLY_LENGTH - 1] , 
                          udp_tvalid_dly[DLY_LENGTH - 1],
                          udp_tlast_dly[DLY_LENGTH - 1],
                          udp_tuser_dly[DLY_LENGTH-1]};
end


xpm_sync_fifo #(
    .WIDTH     	(75      ),
    .DEPTH     	(11      ),
    .FIFO_TYPE 	("fwft"  ))
udp_data_fifo(
    .clk         	(rx_axis_aclk           ),
    .rst_n       	(rx_axis_aresetn        ),
    .wr_en       	(udp_data_fifo_wren     ),
    .rd_en       	(udp_data_fifo_rden     ),
    .data        	(udp_data_fifo_data     ),
    .dout        	(udp_data_fifo_dout     ),
    .full        	(         ),
    .empty       	(  ),
    .almost_full 	(  )
);


/* **************************************************************************
 * Send the received udp data packet to the user
 ***************************************************************************/


always @(posedge rx_axis_aclk) begin
    if(~rx_axis_aresetn)begin
        udp_send_state      <= UDP_SEND_IDLE;
    end
    else begin
        udp_send_state      <= udp_send_next_state;
    end
end

always @(*) begin
    case (udp_send_state)
        UDP_SEND_IDLE       : begin
            if(~udp_length_fifo_empty)begin
                udp_send_next_state  = UDP_SEND_PAYLOAD;
            end
            else begin
                udp_send_next_state  = UDP_SEND_IDLE;
            end
        end
        UDP_SEND_PAYLOAD    : begin
            if(trans_cnt == udp_packetlen - 1)begin
                udp_send_next_state = UDP_SEND_IDLE;
            end
            else begin
                udp_send_next_state = UDP_SEND_PAYLOAD;
            end
        end
        default: begin
            udp_send_next_state = UDP_SEND_IDLE;
        end
    endcase
end

always @(*) begin
    if(udp_send_state == UDP_SEND_IDLE & (udp_send_state != udp_send_next_state))begin
        udp_length_fifo_rden = 1;
    end
    else begin
        udp_length_fifo_rden = 0;
    end
end

assign udp_packetlen = udp_length_fifo_dout[32:17]   ;
assign udp_recv_len  = (udp_length_fifo_dout[3:1] == 0) ? udp_length_fifo_dout[16:4] -1 :
                                                          udp_length_fifo_dout[16:4];
assign tuser         = udp_length_fifo_dout[0];

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        trans_cnt <= 0;
    end
    else if (udp_send_state == UDP_SEND_PAYLOAD ) begin
        trans_cnt <= trans_cnt + 1;
    end
    
    else begin
        trans_cnt <= 0;
    end
end

always @(*) begin
    if (udp_send_state == UDP_SEND_PAYLOAD) begin
        udp_data_fifo_rden = 1;
    end
    else begin
        udp_data_fifo_rden = 0;
    end
end

always @(posedge rx_axis_aclk) begin
    if((udp_send_state == UDP_SEND_PAYLOAD) & (~tuser))begin
        if (trans_cnt < udp_recv_len) begin
            udp_rx_axis_tdata <= udp_data_fifo_dout[74:11];
            udp_rx_axis_tvalid<= 1;
            if (trans_cnt == udp_recv_len - 1) begin
                case (udp_length_fifo_dout[3:1] )
                    3'b001: udp_rx_axis_tkeep <= 8'h01;
                    3'b010: udp_rx_axis_tkeep <= 8'h03;
                    3'b011: udp_rx_axis_tkeep <= 8'h07;
                    3'b100: udp_rx_axis_tkeep <= 8'h0f;
                    3'b101: udp_rx_axis_tkeep <= 8'h1f;
                    3'b110: udp_rx_axis_tkeep <= 8'h3f;
                    3'b111: udp_rx_axis_tkeep <= 8'h7f;
                    default: begin
                        udp_rx_axis_tkeep <= 8'hff;
                    end
                endcase
                udp_rx_axis_tlast <= 1;
                udp_rx_axis_tuser <= tuser;
            end
            else begin
                udp_rx_axis_tkeep <= 8'hff;
                udp_rx_axis_tlast <= 0;
                udp_rx_axis_tuser <= tuser;       
            end
        end
        else begin
            udp_rx_axis_tdata <= 0;
            udp_rx_axis_tkeep <= 0;
            udp_rx_axis_tvalid<= 0;
            udp_rx_axis_tlast <= 0;
            udp_rx_axis_tuser <= 0;           
        end
    end
    else begin
        udp_rx_axis_tdata <= 0;
        udp_rx_axis_tkeep <= 0;
        udp_rx_axis_tvalid<= 0;
        udp_rx_axis_tlast <= 0;
        udp_rx_axis_tuser <= 0;         
    end
end

endmodule

