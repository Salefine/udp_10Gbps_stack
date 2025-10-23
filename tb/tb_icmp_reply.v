/****************************************************************************
 * @file    tb_icmp_reply.v
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

FPGA ---> host icmp data packet
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Type = 0    |   Code = 0    |        Checksum = 0x20ed      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Identifier = 0x4d7c     |    Sequence Number = 0x0001  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           Data (8 bytes)                      |
|                   0x61 0x62 0x63 0x64                         |
|                   0x65 0x66 0x67 0x68                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ */

`timescale 1ns/1ps


`define CLOCK_PERIOD 100

module tb_icmp_reply();

reg             rx_axis_aclk    =   0;
reg             rx_axis_aresetn =   0;
/* ip rx axis interface */
reg [63:0]      ip_rx_axis_tdata    =   0;
reg [7:0]     	ip_rx_axis_tkeep    =   0;
reg             ip_rx_axis_tvalid   =   0;
reg             ip_rx_axis_tlast    =   0;
reg             ip_rx_axis_tusr     =   0;
/* udp rx axis interface */
wire [63:0]     icmp_rx_axis_tdata  ;
wire [7:0]     	icmp_rx_axis_tkeep  ;
wire            icmp_rx_axis_tvalid ;		 
wire            icmp_rx_axis_tlast  ;
reg             icmp_rx_axis_tready = 1;

wire            icmp_not_empty ;

reg [255:0] icmp_data_clear = 0;

initial begin
    #(`CLOCK_PERIOD*60)begin
        rx_axis_aresetn = 0;
    end
    #(`CLOCK_PERIOD*20)begin
        rx_axis_aresetn = 1;
    end
    #(`CLOCK_PERIOD*20)
/*
host ---> FPGA send an icmp data packet                                 FPGA--->host
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 
|   Type = 8    |   Code = 0    |        Checksum = 0x18ed      |      |   Type = 0    |   Code = 0    |        Checksum = 0x20ed      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Identifier = 0x4d7c     |    Sequence Number = 0x0001  |      |        Identifier = 0x4d7c     |    Sequence Number = 0x0001  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           Data (8 bytes)                      |      |                           Data (8 bytes)                      |
|                   0x61 0x62 0x63 0x64                         |      |                   0x61 0x62 0x63 0x64                         |
|                   0x65 0x66 0x67 0x68                         |      |                   0x65 0x66 0x67 0x68                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
*/    
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata <= {16'h0100, 16'h7c4d, 16'hed18, 16'h0008 };
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata <= {16'h6867, 16'h6665, 16'h6463, 16'h6261 };
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 1;
        ip_rx_axis_tusr  <= 0;
    end
    repeat(10)begin
        #(`CLOCK_PERIOD)begin
            ip_rx_axis_tdata <= 0;
            ip_rx_axis_tkeep <= 8'h00;
            ip_rx_axis_tvalid<= 0;
            ip_rx_axis_tlast <= 0;
            ip_rx_axis_tusr  <= 0;
        end    
    end

/*
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 
|   Type = 8    |   Code = 0    |        Checksum = 0x1d52       |  |   Type = 0    |   Code = 0    |        Checksum = 0x2552       | 
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  
|        Identifier = 0x1234     |    Sequence Number = 0x0005   |  |        Identifier = 0x1234     |    Sequence Number = 0x0005   | 
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++   
|                           Data (32 bytes)                      |  |                           Data (32 bytes)                      | 
| 0x48 0x65 0x6c 0x6c 0x6f 0x49 0x43 0x4d 0x50 0x54 0x65 0x73    |  | 0x48 0x65 0x6c 0x6c 0x6f 0x49 0x43 0x4d 0x50 0x54 0x65 0x73    | 
| 0x74 0x50 0x61 0x63 0x6b 0x65 0x74 0x31 0x32 0x33 0x34 0x35    |  | 0x74 0x50 0x61 0x63 0x6b 0x65 0x74 0x31 0x32 0x33 0x34 0x35    | 
| 0x36 0x37 0x38 0x39 0x21 0x21 0x00 0x00                        |  | 0x36 0x37 0x38 0x39 0x21 0x21 0x00 0x00                        | 
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++   
*/
    icmp_data_clear = {
        64'h0000212139383736,  // 周期4: "6789!!" + padding
        64'h353433323174656b,  // 周期3: "ket12345"
        64'h6361507473655450,  // 周期2: "PtestPack"
        64'h4d43496f6c6c6548   // 周期1: "HelloICM"
    };
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata <= {16'h0500, 16'h3412, 16'h521d, 16'h0008 };
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata <= icmp_data_clear[63:0];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata <= icmp_data_clear[127:64];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata <= icmp_data_clear[191:128];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata <= icmp_data_clear[255:192];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 1;
        ip_rx_axis_tusr  <= 0;
    end
    repeat(20)begin
        #(`CLOCK_PERIOD)begin
            ip_rx_axis_tdata <= 0;
            ip_rx_axis_tkeep <= 8'h00;
            ip_rx_axis_tvalid<= 0;
            ip_rx_axis_tlast <= 0;
            ip_rx_axis_tusr  <= 0;
        end    
    end
/*
 error icmp packet
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 
|   Type = 8    |   Code = 0    |        Checksum = 0x254a       |  |   Type = 0    |   Code = 0    |        Checksum = 0xe012       | 
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  
|        Identifier = 0x1234     |    Sequence Number = 0x0005   |  |        Identifier = 0x1234     |    Sequence Number = 0x0005   | 
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++   
|                           Data (32 bytes)                      |  |                           Data (32 bytes)                      | 
| 0x48 0x65 0x6c 0x6c 0x6f 0x49 0x43 0x4d 0x50 0x54 0x65 0x73    |  | 0x48 0x65 0x6c 0x6c 0x6f 0x49 0x43 0x4d 0x50 0x54 0x65 0x73    | 
| 0x74 0x50 0x61 0x63 0x6b 0x65 0x74 0x31 0x32 0x33 0x34 0x35    |  | 0x74 0x50 0x61 0x63 0x6b 0x65 0x74 0x31 0x32 0x33 0x34 0x35    | 
| 0x36 0x37 0x38 0x39 0x21 0x21 0x00 0x00                        |  | 0x36 0x37 0x38 0x39 0x21 0x21 0x00 0x00                        | 
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++   
*/ 
    #(`CLOCK_PERIOD) begin
        ip_rx_axis_tdata <= {16'h0500, 16'h1234, 16'h4a25, 16'h0008};
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end

    #(`CLOCK_PERIOD) begin
        ip_rx_axis_tdata <= icmp_data_clear[255:192];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD) begin
        ip_rx_axis_tdata <= icmp_data_clear[191:128];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD) begin
        ip_rx_axis_tdata <= icmp_data_clear[127:64];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD) begin
        ip_rx_axis_tdata <= icmp_data_clear[63:0];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 1;
        ip_rx_axis_tusr  <= 0;
    end
    repeat(20)begin
        #(`CLOCK_PERIOD)begin
            ip_rx_axis_tdata <= 0;
            ip_rx_axis_tkeep <= 8'h00;
            ip_rx_axis_tvalid<= 0;
            ip_rx_axis_tlast <= 0;
            ip_rx_axis_tusr  <= 0;
        end    
    end
/*
request                                                             reply
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Type = 8    |   Code = 0    |        Checksum = 0x18a8      |   |   Type = 0    |   Code = 0    |        Checksum = 0x20a8      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      Identifier = 0x4d7c      |    Sequence Number = 0x0001   |   |      Identifier = 0x4d7c      |    Sequence Number = 0x0001   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Data ("hello,world")                  |   |                         Data ("hello,world")                  |
|   0x68 0x65 0x6c 0x6c 0x6f 0x2c 0x77 0x6f                     |   |   0x68 0x65 0x6c 0x6c 0x6f 0x2c 0x77 0x6f                     |
|   0x72 0x6c 0x64                                              |   |   0x72 0x6c 0x64                                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
*/
    icmp_data_clear = {
        64'h0,
        64'h0,
        64'h0000000000646c72,  
        64'h6f772c6f6c6c6568
    };
    #(`CLOCK_PERIOD) begin
        ip_rx_axis_tdata <= {16'h0100, 16'h7c4d, 16'ha818, 16'h0008};
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end

    #(`CLOCK_PERIOD) begin
        ip_rx_axis_tdata <= icmp_data_clear[63:0];
        ip_rx_axis_tkeep <= 8'hff;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end
    #(`CLOCK_PERIOD) begin
        ip_rx_axis_tdata <= icmp_data_clear[127:64];
        ip_rx_axis_tkeep <= 8'h07;
        ip_rx_axis_tvalid<= 1;
        ip_rx_axis_tlast <= 1;
        ip_rx_axis_tusr  <= 0;
    end

    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata <= 0;
        ip_rx_axis_tkeep <= 8'h00;
        ip_rx_axis_tvalid<= 0;
        ip_rx_axis_tlast <= 0;
        ip_rx_axis_tusr  <= 0;
    end  
end

us_icmp_reply u_us_icmp_reply(
    .rx_axis_aclk        	(rx_axis_aclk         ),
    .rx_axis_aresetn     	(rx_axis_aresetn      ),
    .ip_rx_axis_tdata    	(ip_rx_axis_tdata     ),
    .ip_rx_axis_tkeep    	(ip_rx_axis_tkeep     ),
    .ip_rx_axis_tvalid   	(ip_rx_axis_tvalid    ),
    .ip_rx_axis_tlast    	(ip_rx_axis_tlast     ),
    .ip_rx_axis_tuser     	(ip_rx_axis_tusr      ),
    .icmp_tx_axis_tdata  	(icmp_rx_axis_tdata   ),
    .icmp_tx_axis_tkeep  	(icmp_rx_axis_tkeep   ),
    .icmp_tx_axis_tvalid 	(icmp_rx_axis_tvalid  ),
    .icmp_tx_axis_tlast  	(icmp_rx_axis_tlast   ),
    .icmp_tx_axis_tready 	(icmp_rx_axis_tready  ),
    .icmp_not_empty      	(icmp_not_empty       )
);

always #(`CLOCK_PERIOD/2) rx_axis_aclk = ~rx_axis_aclk;

endmodule

