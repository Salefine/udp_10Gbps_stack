/****************************************************************************
 * @file    us_arp_rx.v
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

module us_arp_rx(
    input   wire        rx_axis_aclk,
    input   wire        rx_axis_aresetn,

    input   wire  [63:0]rx_axis_fmac_tdata,
    input   wire  [7:0] rx_axis_fmac_tkeep,
    input   wire        rx_axis_fmac_tvalid,
    input   wire        rx_axis_fmac_tlast,
    input   wire        rx_axis_fmac_tuser,

    input   [47:0]      local_mac_addr ,
    input   [31:0]      local_ip_addr  ,
    input   [31:0]      dst_ip_addr    ,

    output  reg         arp_reply_req,
    input               arp_reply_ack,
    output  reg         arp_reply_valid,

    output  reg[47:0]      recv_src_mac_addr,
    output  reg[31:0]      recv_src_ip_addr
);
    

localparam ARP_REQUEST_CODE = 16'h0001 ;	//arp request code parameter
localparam ARP_REPLY_CODE   = 16'h0002 ;	//arp reply code parameter

reg        [15:0]   recv_op = 0;
// reg        [31:0]	rcvd_src_ip_addr  = 0;	//received source ip address
reg        [31:0]   recv_dst_ip_addr  = 0;		//received destination ip address
reg        [47:0]	recv_dst_mac_addr = 0;		//received destination mac address
reg        [31:0]   timeout           = 0;
/* **********************************************************************
 * arp receive state machine
 **********************************************************************/
localparam [8:0]    ARP_RECV_DATA0 = 9'b000000001;
localparam [8:0]    ARP_RECV_DATA1 = 9'b000000010;
localparam [8:0]    ARP_RECV_DATA2 = 9'b000000100;
localparam [8:0]    ARP_RECV_DATA3 = 9'b000001000;
localparam [8:0]    ARP_RECV_DATA  = 9'b000010000;

localparam [8:0]    ARP_RECV_GOOD    =  9'b000100000;
localparam [8:0]    ARP_RECV_FAIL    =  9'b001000000;
localparam [8:0]    ARP_RCV_REQUEST  =  9'b010000000 ;	
localparam [8:0]    ARP_RCV_REPLY    =  9'b100000000 ;	


reg        [9:0]    arp_recv_state      = 0;
reg        [9:0]    arp_recv_next_state = 0;


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        arp_recv_state  <= ARP_RECV_DATA0;
    end
    else begin
        arp_recv_state <= arp_recv_next_state;
    end
end

always @(*) begin
    case (arp_recv_state)
        ARP_RECV_DATA0 : begin
            if (rx_axis_fmac_tvalid & (~rx_axis_fmac_tlast)) begin
                arp_recv_next_state  <= ARP_RECV_DATA1;
            end
            else if (rx_axis_fmac_tvalid & rx_axis_fmac_tlast) begin
                arp_recv_next_state <= ARP_RECV_FAIL;
            end
            else begin
                arp_recv_next_state  <= ARP_RECV_DATA0;
            end
        end
        ARP_RECV_DATA1 : begin
            if (rx_axis_fmac_tvalid & (~rx_axis_fmac_tlast)) begin
                arp_recv_next_state  <= ARP_RECV_DATA2;
            end
            else if (rx_axis_fmac_tvalid & rx_axis_fmac_tlast)begin
                arp_recv_next_state <= ARP_RECV_FAIL;
            end
            else begin
                arp_recv_next_state  <= ARP_RECV_DATA0;
            end            
        end
        ARP_RECV_DATA2 : begin
            if (rx_axis_fmac_tvalid & (~rx_axis_fmac_tlast)) begin
                arp_recv_next_state  <= ARP_RECV_DATA3;
            end
            else if (rx_axis_fmac_tvalid & rx_axis_fmac_tlast)begin
                arp_recv_next_state <= ARP_RECV_FAIL;
            end
            else begin
                arp_recv_next_state  <= ARP_RECV_DATA0;
            end            
        end
        ARP_RECV_DATA3 : begin
            if (rx_axis_fmac_tvalid & (~rx_axis_fmac_tlast)) begin
                arp_recv_next_state  <= ARP_RECV_DATA;
            end
            else if (rx_axis_fmac_tvalid & (rx_axis_fmac_tlast) & (~rx_axis_fmac_tuser)) begin
                arp_recv_next_state  <= ARP_RECV_GOOD;
            end
            else if (rx_axis_fmac_tvalid & (rx_axis_fmac_tlast) & (rx_axis_fmac_tuser)) begin
                arp_recv_next_state  <= ARP_RECV_FAIL;
            end            
            else begin
                arp_recv_next_state  <= ARP_RECV_DATA3;
            end            
        end        

        ARP_RECV_DATA : begin
            if (rx_axis_fmac_tvalid & (rx_axis_fmac_tlast) & (~rx_axis_fmac_tuser)) begin
                arp_recv_next_state  <= ARP_RECV_GOOD;
            end
            else if (rx_axis_fmac_tvalid & (rx_axis_fmac_tlast) & (rx_axis_fmac_tuser)) begin
                arp_recv_next_state  <= ARP_RECV_FAIL;
            end
            else begin
                arp_recv_next_state  <= ARP_RECV_DATA0;
            end    
        end

        ARP_RECV_FAIL  : begin
            arp_recv_next_state  <= ARP_RECV_DATA0;
        end
        ARP_RECV_GOOD  : begin
            if (recv_op == ARP_REQUEST_CODE & (local_ip_addr == recv_dst_ip_addr) & (recv_src_ip_addr == dst_ip_addr)) begin
                arp_recv_next_state  <= ARP_RCV_REQUEST;
            end
            else if (recv_op == ARP_REPLY_CODE & (local_ip_addr == recv_dst_ip_addr) & (recv_src_ip_addr == dst_ip_addr) & (local_mac_addr == recv_dst_mac_addr)) begin
                arp_recv_next_state  <= ARP_RCV_REPLY;
            end
            else begin
                arp_recv_next_state  <= ARP_RECV_DATA0;
            end
        end        
        ARP_RCV_REQUEST : begin
            if (arp_reply_ack) begin
                arp_recv_next_state <= ARP_RECV_DATA0;
            end
            else if (timeout == 32'd1000000) begin
                arp_recv_next_state <= ARP_RECV_DATA0;
            end
            else begin
                arp_recv_next_state <= ARP_RCV_REQUEST;
            end
        end
        ARP_RCV_REPLY   : begin
            arp_recv_next_state  <= ARP_RECV_DATA0;
        end
        default: begin
            arp_recv_next_state  <= ARP_RECV_DATA0;
        end
    endcase
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_op  <= 0;
    end
    else if (arp_recv_state == ARP_RECV_DATA0 &(arp_recv_state != arp_recv_next_state)) begin
        recv_op  <= {rx_axis_fmac_tdata[55:48], rx_axis_fmac_tdata[63:56]};
    end
    else begin
        recv_op <= recv_op;
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        timeout  <=  0;
    end
    else if (arp_recv_state == ARP_RCV_REQUEST) begin
        timeout <= timeout + 1;
    end
    else begin
        timeout  <=  0;
    end
end


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_src_mac_addr  <= 0;
        recv_src_ip_addr   <= 0;
    end
    else if (arp_recv_state == ARP_RECV_DATA1 & rx_axis_fmac_tvalid) begin
        recv_src_mac_addr <= {
                                rx_axis_fmac_tdata[7:0],  rx_axis_fmac_tdata[15:8], rx_axis_fmac_tdata[23:16],
                                rx_axis_fmac_tdata[31:24],rx_axis_fmac_tdata[39:32],rx_axis_fmac_tdata[47:40]
                            };
        recv_src_ip_addr[31:16] <= {
                                rx_axis_fmac_tdata[55:48],rx_axis_fmac_tdata[63:56]
                            };
    end
    else if(arp_recv_state == ARP_RECV_DATA2 & rx_axis_fmac_tvalid)begin
        recv_src_ip_addr[15:0]  <= {
                                       rx_axis_fmac_tdata[7:0], rx_axis_fmac_tdata[15:8] 
                                    };
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_dst_mac_addr <= 0;
    end
    else if(arp_recv_state == ARP_RECV_DATA2 & rx_axis_fmac_tvalid) begin
        recv_dst_mac_addr       <= {
                                        rx_axis_fmac_tdata[23:16], rx_axis_fmac_tdata[31:24], rx_axis_fmac_tdata[39:32],
                                        rx_axis_fmac_tdata[47:40], rx_axis_fmac_tdata[55:48], rx_axis_fmac_tdata[63:56]
                                    };
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_dst_ip_addr <= 0;
    end
    else if (arp_recv_state == ARP_RECV_DATA3 & rx_axis_fmac_tvalid) begin
        recv_dst_ip_addr       <= {
                                        rx_axis_fmac_tdata[7:0],  rx_axis_fmac_tdata[15:8],
                                        rx_axis_fmac_tdata[23:16],rx_axis_fmac_tdata[31:24]
                                    };
    end    
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        arp_reply_req <= 0;
    end else if (arp_recv_state == ARP_RCV_REQUEST) begin
        arp_reply_req <= 1;
    end else if (arp_reply_ack || arp_recv_state == ARP_RECV_DATA0) begin
        arp_reply_req <= 0;
    end

end


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        arp_reply_valid <= 0;
    end else if (arp_recv_state == ARP_RCV_REPLY || arp_recv_state == ARP_RCV_REQUEST) begin
        arp_reply_valid <= 1;
    end else begin
        arp_reply_valid <= 0;
    end
end


endmodule //us_arp_rx

