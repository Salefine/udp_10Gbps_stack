/****************************************************************************
 * @file    tb_xpm_sync_fifo.v
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

`define CLOCK_PERIOD  100

 module tb_xpm_sync_fifo();

parameter WIDTH = 8 ;			//This is width
parameter DEPTH = 8 ;   		//This is depth
parameter FIFO_TYPE = "std" ;  //std or fwft


reg                  	clk  = 0;
reg                  	rst_n= 0;
reg                  	wr_en= 0;
reg                  	rd_en= 0;
reg   [WIDTH-1:0] 		data = 0;
wire  [WIDTH-1:0] 		dout;
wire              		full;
wire              		empty;
wire					almost_full;



xpm_sync_fifo #(
    .WIDTH     	(8     ),
    .DEPTH     	(8     ),
    .FIFO_TYPE 	("std"  ))
u_xpm_sync_fifo(
    .clk         	(clk          ),
    .rst_n       	(rst_n        ),
    .wr_en       	(wr_en        ),
    .rd_en       	(rd_en        ),
    .data        	(data         ),
    .dout        	(dout         ),
    .full        	(full         ),
    .empty       	(empty        ),
    .almost_full 	(almost_full  )
);

initial begin
    #(`CLOCK_PERIOD * 20) rst_n <= 1;
    repeat(100)begin
        #(`CLOCK_PERIOD / 2)begin
            wr_en <= 1;
            data <= data + 1'b1;
        end
        wr_en <= 0;
    end

    repeat(100) begin
        #(`CLOCK_PERIOD / 2)begin
            rd_en <= 1;
        end
        rd_en <= 0;
    end
    
end

always #(`CLOCK_PERIOD / 2)  clk = ~clk;

endmodule