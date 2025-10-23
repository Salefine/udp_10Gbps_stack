/****************************************************************************
 * @file    axis_counter.v
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
module axis_counter (
    input   wire        axis_aclk,
    input   wire        axis_aresetn,
    input   wire        axis_tvalid,
    input   wire        axis_tready,
    input   wire[63:0]  axis_tdata,
    input   wire        axis_tlast,
    input   wire[7:0]   axis_tkeep,
    output  reg [15:0]  packet_len_bytes
);
    
reg [15:0] r_packet_len_bytes;

// 使用查找表计算有效字节数
function [3:0] count_keep_bytes;
    input [7:0] keep;
    begin
        case (keep)
            8'b00000001: count_keep_bytes = 1;
            8'b00000011: count_keep_bytes = 2;
            8'b00000111: count_keep_bytes = 3;
            8'b00001111: count_keep_bytes = 4;
            8'b00011111: count_keep_bytes = 5;
            8'b00111111: count_keep_bytes = 6;
            8'b01111111: count_keep_bytes = 7;
            8'b11111111: count_keep_bytes = 8;
            default:     count_keep_bytes = 0; // 包括8'b00000000和其他情况
        endcase
    end
endfunction

wire [3:0] valid_bytes = count_keep_bytes(axis_tkeep);

always @(posedge axis_aclk) begin
    if (~axis_aresetn) begin
        r_packet_len_bytes <= 0;
        packet_len_bytes <= 0;
    end
    else if (axis_tvalid & axis_tready) begin
        if (axis_tlast) begin
            packet_len_bytes <= r_packet_len_bytes + valid_bytes;
            r_packet_len_bytes <= 0;
        end
        else begin
            r_packet_len_bytes <= r_packet_len_bytes + valid_bytes;
        end
    end
end

endmodule



