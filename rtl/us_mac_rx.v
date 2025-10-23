/****************************************************************************
 * @file    us_mac_frame_rx.v
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

/*****************************************************************************

+-------------------+-------------------+-------------------+-------------------+
|   Preamble (7B)   |   SFD (1B)        |                   |                   |
| 10101010...       | 10101011          |                   |                   |
+-------------------+-------------------+-------------------+-------------------+
|                        Destination MAC Address (6B)                           |
+-------------------------------------------------------------------------------+
|                          Source MAC Address (6B)                              |
+-------------------------------------------------------------------------------+
|   EtherType / Length (2B)   |                                              ...|
+-----------------------------+-------------------------------------------------+
|                         Payload / Data (46 ~ 1500B)                           |
|   (if <46B, pad with zeros to reach minimum frame size)                       |
+-------------------------------------------------------------------------------+
|                  Frame Check Sequence (FCS, CRC-32, 4B)                       |
+-------------------------------------------------------------------------------+

*****************************************************************************/

/*****************************************************************************
timing diagram

https://wavedrom.com/editor.html

{signal: [
  {name: 'source_clk'  ,  wave: 'n...........', period:1}, 
  {name: 'tvalid'      ,  wave: '01.......0|'},
  {name: 'tdata[7:0]'  ,  wave: '3452222229|',data:["xx","DA","SA","D","D","D","D","D","D"]},
  {name: 'tdata[15:8]' ,  wave: '3452222229|',data:["xx","DA","SA","D","D","D","D","D","D"]},
  {name: 'tdata[23:16]',  wave: '345222229.|',data:["xx","DA","SA","D","D","D","D","D",""]},
  {name: 'tdata[31:24]',  wave: '345222229.|',data:["xx","DA","SA","D","D","D","D","D",""]},
  {name: 'tdata[39:32]',  wave: '346222229.|',data:["xx","DA","L/T" ,"D","D","D","D","D",""]},
  {name: 'tdata[47:40]',  wave: '346222229.|',data:["xx","DA","L/T" ,"D","D","D","D","D",""]},
  {name: 'tdata[55:48]',  wave: '352222229.|',data:["xx","SA","D" ,"D","D","D","D","D",""]},
  {name: 'tdata[63:56]',  wave: '352222229.|',data:["xx","SA","D" ,"D","D","D","D","D",""]},
  {name: 'tkeep[7:0]'  ,  wave: '32......89|',data:["xx","0xff","0x3"]},
  {name: 'tuser'       ,  wave: '0..........'},
  {name: 'tlast'       ,  wave: '0.......10.'},
]}

*****************************************************************************/


`timescale 1ns/1ps

module us_mac_rx(
    input       wire        rx_axis_aclk        ,
    input       wire        rx_axis_aresetn     ,

    input       wire[63:0]  rx_mac_axis_tdata   ,
    input       wire[7:0]   rx_mac_axis_tkeep   ,
    input       wire        rx_mac_axis_tvalid  ,
    input       wire        rx_mac_axis_tuser   ,
    input       wire        rx_mac_axis_tlast   ,

    output      reg[63:0]   rx_frame_axis_tdata ,
    output      reg[7:0]    rx_frame_axis_tkeep ,
    output      reg         rx_frame_axis_tvalid,
    output      reg         rx_frame_axis_tuser ,
    output      reg         rx_frame_axis_tlast ,

    output      reg[47:0]   recv_dst_mac_addr   ,
    output      reg[47:0]   recv_src_mac_addr   ,
    output      reg[15:0]   recv_type           ,
    input       wire[47:0]  local_mac_addr  

);
    

/* **********************************************************************
 * 1. store machine for receive mac frame
 **********************************************************************/

localparam RECV_MAC_DATA0   = 5'b00001;
localparam RECV_MAC_DATA1   = 5'b00010;
localparam RECV_PAYLOAD     = 5'b00100;
localparam RECV_GOOD        = 5'b01000;
localparam RECV_FAIL        = 5'b10000;

reg     [4:0]   recv_state       = 0;
reg     [4:0]   recv_next_state  = 0;

reg     [63:0]  rx_mac_axis_tdata_reg   =   0;

reg     rx_frame_axis_tuser_reg    =   0;

always @(posedge rx_axis_aclk) begin
    rx_frame_axis_tuser_reg <= rx_mac_axis_tuser;
end



always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_state      <= RECV_MAC_DATA0;
    end
    else begin
        recv_state      <= recv_next_state;
    end
end

always @(*) begin
    case (recv_state)
        RECV_MAC_DATA0 : begin
            if (rx_mac_axis_tvalid & ~rx_mac_axis_tlast) begin
                recv_next_state <= RECV_MAC_DATA1;
            end
            else if(rx_mac_axis_tvalid & rx_mac_axis_tlast)begin
                recv_next_state <= RECV_FAIL;
            end
            else begin
                recv_next_state <= RECV_MAC_DATA0;
            end
        end

        RECV_MAC_DATA1: begin
            if (rx_mac_axis_tvalid & ~rx_mac_axis_tlast) begin
                recv_next_state <= RECV_PAYLOAD;
            end
            else if (rx_mac_axis_tvalid & rx_mac_axis_tlast) begin
                recv_next_state <= RECV_FAIL;
            end
            else begin
                recv_next_state <= RECV_MAC_DATA0;
            end            
        end

        RECV_PAYLOAD : begin
            if (rx_mac_axis_tvalid & rx_mac_axis_tlast & rx_mac_axis_tuser) begin
                recv_next_state <= RECV_FAIL;
            end
            else if (rx_mac_axis_tvalid & rx_mac_axis_tlast & ~rx_mac_axis_tuser) begin
                recv_next_state <= RECV_GOOD;
            end
            else begin
                recv_next_state <= RECV_PAYLOAD;
            end
        end

        RECV_GOOD :begin
            recv_next_state <= RECV_MAC_DATA0;
        end

        RECV_FAIL :begin
            recv_next_state <= RECV_MAC_DATA0;
        end

        default: begin
            recv_next_state <= RECV_MAC_DATA0;
        end
    endcase
end

/* **********************************************************************
 * 2. process src mac , dst mac and tdata
 **********************************************************************/

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_dst_mac_addr   <=  48'h0;
    end
    else if (rx_mac_axis_tvalid & ~rx_mac_axis_tlast & (recv_state == RECV_MAC_DATA0)) begin
        recv_dst_mac_addr[47:40] <= rx_mac_axis_tdata[7:0];
        recv_dst_mac_addr[39:32] <= rx_mac_axis_tdata[15:8];
        recv_dst_mac_addr[31:24] <= rx_mac_axis_tdata[23:16];
        recv_dst_mac_addr[23:16] <= rx_mac_axis_tdata[31:24];
        recv_dst_mac_addr[15:8]  <= rx_mac_axis_tdata[39:32];
        recv_dst_mac_addr[7:0]   <= rx_mac_axis_tdata[47:40];
    end
    else begin
        
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_src_mac_addr   <=  48'h0;
    end
    else if (recv_state == RECV_MAC_DATA0) begin
        recv_src_mac_addr[47:40] <= rx_mac_axis_tdata_reg[55:48];
        recv_src_mac_addr[39:32] <= rx_mac_axis_tdata_reg[63:56];
    end
    else if (recv_next_state == RECV_MAC_DATA1) begin
        recv_src_mac_addr[31:24] <= rx_mac_axis_tdata[7:0];
        recv_src_mac_addr[23:16] <= rx_mac_axis_tdata[15:8];
        recv_src_mac_addr[15:8]  <= rx_mac_axis_tdata[23:16];
        recv_src_mac_addr[7:0]   <= rx_mac_axis_tdata[31:24];
    end    
    else begin
        
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_type  <= 0;
    end
    else if (recv_state == RECV_MAC_DATA1 & rx_mac_axis_tvalid) begin
        recv_type[15:8] <= rx_mac_axis_tdata[39:32];
        recv_type[7:0]  <= rx_mac_axis_tdata[47:40];
    end
    else begin
        recv_type <= recv_type;
    end
end        

always @(posedge rx_axis_aclk) begin
    rx_mac_axis_tdata_reg <= rx_mac_axis_tdata;
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        rx_frame_axis_tdata <= 0;
    end
    else if (recv_state == RECV_PAYLOAD & rx_mac_axis_tvalid || recv_state == RECV_GOOD || recv_state == RECV_FAIL) begin
        rx_frame_axis_tdata[7:0]    <= rx_mac_axis_tdata_reg[55:48];
        rx_frame_axis_tdata[15:8]   <= rx_mac_axis_tdata_reg[63:56];             
        rx_frame_axis_tdata[23:16]  <= rx_mac_axis_tdata[7:0];
        rx_frame_axis_tdata[31:24]  <= rx_mac_axis_tdata[15:8];     
        rx_frame_axis_tdata[39:32]  <= rx_mac_axis_tdata[23:16];
        rx_frame_axis_tdata[47:40]  <= rx_mac_axis_tdata[31:24];             
        rx_frame_axis_tdata[55:48]  <= rx_mac_axis_tdata[39:32];
        rx_frame_axis_tdata[63:56]  <= rx_mac_axis_tdata[47:40];           
    end
    else begin
        rx_frame_axis_tdata <= rx_frame_axis_tdata;
    end
end

/* **********************************************************************
 * 3. process tkeep tlast tuser signals
 **********************************************************************/
reg     [7:0]   rx_mac_axis_tkeep_reg   =   0;
//reg     [7:0]   rx_mac_axis_tuser_reg   =   0;

always @(posedge rx_axis_aclk) begin
    rx_mac_axis_tkeep_reg <= rx_mac_axis_tkeep;
//    rx_mac_axis_tuser_reg <= rx_mac_axis_tuser;
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        rx_frame_axis_tvalid    <= 0;
    end
    else if (recv_dst_mac_addr != local_mac_addr && recv_dst_mac_addr != 48'hff_ff_ff_ff_ff_ff) begin
        rx_frame_axis_tvalid    <= 0;
    end
    else if (recv_state == RECV_PAYLOAD & rx_mac_axis_tvalid) begin
        rx_frame_axis_tvalid    <= 1;
    end
    else if (recv_state == RECV_GOOD || recv_state == RECV_FAIL) begin
        if (rx_mac_axis_tkeep_reg[7:6] != 0) begin
            rx_frame_axis_tvalid <= 1;
        end
        else begin
            rx_frame_axis_tvalid <= 0;
        end
    end
    else begin
        rx_frame_axis_tvalid <= 0;
    end
end


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        rx_frame_axis_tkeep     <=  0;
        rx_frame_axis_tuser     <=  0;
    end
    else if (recv_state == RECV_PAYLOAD && (recv_state == recv_next_state)) begin
        rx_frame_axis_tkeep <= 8'hff;
        rx_frame_axis_tuser <=  0;
    end
    else if (recv_state == RECV_PAYLOAD && (recv_state != recv_next_state)) begin
        if (rx_mac_axis_tkeep[7:6] != 2'b00) begin
            rx_frame_axis_tkeep <= 8'hff;
            rx_frame_axis_tuser <=  0;
        end
        else begin
            rx_frame_axis_tuser <=  rx_mac_axis_tuser;
            rx_frame_axis_tkeep <= {rx_mac_axis_tkeep[5:0],2'b11};
        end
    end
    else if (recv_state == RECV_GOOD || recv_state == RECV_FAIL) begin
        if (rx_frame_axis_tlast) begin
            rx_frame_axis_tkeep <= 8'h00;
            rx_frame_axis_tuser <=  0;
        end
        else begin
            rx_frame_axis_tuser <=  rx_frame_axis_tuser_reg;
            rx_frame_axis_tkeep <= rx_mac_axis_tkeep_reg >> 6;
        end
    end
    else begin
        rx_frame_axis_tuser     <= 0;
        rx_frame_axis_tkeep     <=  0;    
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        rx_frame_axis_tlast <= 0;
    end
    else if (recv_state == RECV_PAYLOAD && (recv_next_state != recv_state)) begin
        if (rx_mac_axis_tkeep == 8'h7f || rx_mac_axis_tkeep == 8'hff) begin
            rx_frame_axis_tlast <= 0;
        end
        else begin
            rx_frame_axis_tlast <= 1;
        end
    end
    else if (recv_state == RECV_GOOD || recv_state == RECV_FAIL) begin
        if (rx_frame_axis_tlast) begin
            rx_frame_axis_tlast <= 0;
        end
        else begin
            rx_frame_axis_tlast <= 1;
        end
    end
    else begin
        rx_frame_axis_tlast <= 0;
    end
end



endmodule //us_mac_rx

