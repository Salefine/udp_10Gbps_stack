/****************************************************************************
 * @file    us_ip_tx_mode.v
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

`timescale 1ns/1ps

module us_ip_tx_mode(
    	input                			tx_axis_aclk,
        input                			tx_axis_aresetn,  
		/* ip tx axis interface */	
		output reg [63:0]        		ip_tx_axis_tdata,
        output reg [7:0]     	  		ip_tx_axis_tkeep,
        output reg               		ip_tx_axis_tvalid,		 
        output reg               		ip_tx_axis_tlast,
        input 	  	         			ip_tx_axis_tready,
        /* udp tx axis interface */	
		input  [63:0]       			udp_tx_axis_tdata,
        input  [7:0]     				udp_tx_axis_tkeep,
        input                           udp_tx_axis_tvalid,
        input                           udp_tx_axis_tlast,
        output reg                      udp_tx_axis_tready,
		/* icmp tx axis interface */	
		input  [63:0]       			icmp_tx_axis_tdata,
        input  [7:0]     				icmp_tx_axis_tkeep,
        input                           icmp_tx_axis_tvalid,
        input                           icmp_tx_axis_tlast,
        output reg                      icmp_tx_axis_tready,
		 
		input                   		udp_not_empty,		//udp data is ready to send
		input                   		icmp_not_empty,     //icmp data is ready to send
        output reg [7:0]        		ip_send_type,       //udp protocol: 8'h11; icmp protocol: 8'h01
		input							recv_ip_end         //receive stream end signal
);

localparam ip_udp_type  = 8'h11 ;
localparam ip_icmp_type = 8'h01 ;
/* *********************************************************************
 * state machine for ip receive udp data or icmp data
 **********************************************************************/
localparam  [3:0]   IP_SEND_IDLE    =   4'b0001;
localparam  [3:0]   IP_SEND_ICMP    =   4'b0010;
localparam  [3:0]   IP_SEND_UDP     =   4'b0100;
localparam  [3:0]   IP_SEND_ENDL    =   4'b1000;

reg         [3:0]   ip_send_state        =  0;
reg         [3:0]   ip_send_next_state   =  0;

always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        ip_send_state       <= IP_SEND_IDLE;
    end else begin
        ip_send_state       <= ip_send_next_state;
    end
end

always @(*) begin
    case (ip_send_state)
        IP_SEND_IDLE : begin
            if (udp_not_empty) begin
                ip_send_next_state  <= IP_SEND_UDP;
            end
            else if (icmp_not_empty) begin
                ip_send_next_state  <= IP_SEND_ICMP;
            end
            else begin
                ip_send_next_state  <= IP_SEND_IDLE;
            end
        end
        IP_SEND_ICMP : begin
            if (recv_ip_end) begin
                ip_send_next_state <= IP_SEND_IDLE;
            end
            else begin
                ip_send_next_state <= IP_SEND_ICMP;
            end
        end
        IP_SEND_UDP  : begin
            if (recv_ip_end) begin
                ip_send_next_state <= IP_SEND_IDLE;
            end
            else begin
                ip_send_next_state <= IP_SEND_UDP;
            end            
        end                       
        default: begin
            ip_send_next_state <= IP_SEND_IDLE;
        end 
    endcase
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        ip_tx_axis_tdata  <= 0;
        ip_tx_axis_tkeep  <= 0;
        ip_tx_axis_tvalid <= 0;
        ip_tx_axis_tlast  <= 0;
        ip_send_type      <= 0; 
    end
    else if (ip_send_state == IP_SEND_UDP) begin
        ip_tx_axis_tdata  <= udp_tx_axis_tdata;
        ip_tx_axis_tkeep  <= udp_tx_axis_tkeep;
        ip_tx_axis_tvalid <= udp_tx_axis_tvalid;
        ip_tx_axis_tlast  <= udp_tx_axis_tlast;   
        udp_tx_axis_tready<= ip_tx_axis_tready;    
        ip_send_type      <= ip_udp_type; 
    end
    else if (ip_send_state == IP_SEND_ICMP) begin
        ip_tx_axis_tdata   <= icmp_tx_axis_tdata;
        ip_tx_axis_tkeep   <= icmp_tx_axis_tkeep;
        ip_tx_axis_tvalid  <= icmp_tx_axis_tvalid;
        ip_tx_axis_tlast   <= icmp_tx_axis_tlast;   
        icmp_tx_axis_tready<= ip_tx_axis_tready;       
        ip_send_type       <= ip_icmp_type;     
    end
    else begin
        ip_tx_axis_tdata  <= 0;
        ip_tx_axis_tkeep  <= 0;
        ip_tx_axis_tvalid <= 0;
        ip_tx_axis_tlast  <= 0;        
        ip_send_type      <= ip_udp_type; 
    end
end

endmodule

