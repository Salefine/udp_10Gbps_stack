/****************************************************************************
 * @file    tb_us_ip_rx.v
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

`define  CLOCK_PERIOD  100

module tb_us_ip_rx();

reg             rx_axis_aclk    =   0;
reg             rx_axis_aresetn =   0;

reg  [63:0]     mac_rx_axis_tdata=  0;
reg  [7:0]      mac_rx_axis_tkeep=  0;
reg             mac_rx_axis_tvalid=0 ;
reg             mac_rx_axis_tlast = 0;
reg             mac_rx_axis_tuser =0 ;

wire [63:0]     ip_rx_axis_tdata    ;
wire [7:0]      ip_rx_axis_tkeep    ;
wire            ip_rx_axis_tvalid   ;
wire            ip_rx_axis_tuser    ;
wire            ip_rx_axis_tlast    ;


reg  [31:0]     local_ip_addr    = {8'd192, 8'd168, 8'd1, 8'd11};
reg  [47:0]     local_mac_addr   = {8'h08,  8'h8f, 8'hc3, 8'he4, 8'h42, 8'h57};
wire [31:0]     recv_dst_ip_addr    ;
wire [31:0]     recv_src_ip_addr ;
reg  [47:0]     recv_dst_mac_addr= {8'h08,  8'h8f, 8'hc3, 8'he4, 8'h42, 8'h57}   ;
wire [15:0]     ip_type             ;

initial begin
    #(`CLOCK_PERIOD * 60)begin
        rx_axis_aresetn <= 0;
    end
    #(`CLOCK_PERIOD)begin
        rx_axis_aresetn <= 1;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h004000001d000045;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tlast <= 0;
        mac_rx_axis_tuser <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0a01a8c069f811ff;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tlast <= 0;
        mac_rx_axis_tuser <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h818080800b01a8c0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tlast <= 0;
        mac_rx_axis_tuser <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h00000001747a0900;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tlast <= 0;
        mac_rx_axis_tuser <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tlast <= 0;
        mac_rx_axis_tuser <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tlast <= 0;
        mac_rx_axis_tuser <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tlast <= 0;
        mac_rx_axis_tuser <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'h03;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tlast <= 1;
        mac_rx_axis_tuser <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'h0;
        mac_rx_axis_tvalid<= 0;
        mac_rx_axis_tlast <= 0;
        mac_rx_axis_tuser <= 0;
    end    
end


us_ip_rx u_us_ip_rx(
    .rx_axis_aclk       	(rx_axis_aclk        ),
    .rx_axis_aresetn    	(rx_axis_aresetn     ),
    .mac_rx_axis_tdata  	(mac_rx_axis_tdata   ),
    .mac_rx_axis_tkeep  	(mac_rx_axis_tkeep   ),
    .mac_rx_axis_tvalid 	(mac_rx_axis_tvalid  ),
    .mac_rx_axis_tuser  	(mac_rx_axis_tuser   ),
    .mac_rx_axis_tlast  	(mac_rx_axis_tlast   ),
    .ip_rx_axis_tdata   	(ip_rx_axis_tdata    ),
    .ip_rx_axis_tkeep   	(ip_rx_axis_tkeep    ),
    .ip_rx_axis_tvalid  	(ip_rx_axis_tvalid   ),
    .ip_rx_axis_tuser   	(ip_rx_axis_tuser    ),
    .ip_rx_axis_tlast   	(ip_rx_axis_tlast    ),
    .local_ip_addr      	(local_ip_addr       ),
    .recv_dst_ip_addr   	(recv_dst_ip_addr    ),
    .recv_src_ip_addr   	(recv_src_ip_addr    ),
    .local_mac_addr     	(local_mac_addr      ),
    .recv_dst_mac_addr  	(recv_dst_mac_addr   ),
    .ip_type            	(ip_type             )
);

always #(`CLOCK_PERIOD / 2) rx_axis_aclk = ~rx_axis_aclk;

endmodule
