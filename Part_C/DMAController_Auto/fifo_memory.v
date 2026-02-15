`timescale 1ns / 1ps

module fifo_memory(input      wclk, rclk, 
                   input      rrst_n,
                   input      wr_enable_fifo, rd_enable_fifo,
                   input      [3:0] b_wr_ptr, b_rd_ptr,
                   input      [31:0] wr_data,
                   output reg [31:0] rd_data
                   );
        
        reg [31:0] mem [0:7];
        
        always@(posedge wclk) begin
                if (wr_enable_fifo) begin
                    mem[b_wr_ptr[2:0]] <= wr_data;
                end                            
        end
          
        /*    
        always@(posedge rclk or negedge rrst_n) begin
            if (!rrst_n) begin
                rd_data <= 8'd0;
            end                                                     //Uncomment if FWFT isn't being applied
            else begin
                if (rd_enable_fifo) begin
                    rd_data <= mem[b_rd_ptr[2:0]];
                end                       
            end          
        end
        */  
        always@(*) begin    
            rd_data = (rd_enable_fifo) ? mem[b_rd_ptr[2:0]] : 8'd0;
        end
        
endmodule
