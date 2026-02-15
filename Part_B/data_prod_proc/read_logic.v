`timescale 1ns / 1ps

module read_logic(input            rclk, 
                  input            rrst_n,
                  input            rd_enable_fifo,
                  input      [3:0] g_wr_ptr_sync,
                  output reg       empty,                 
                  output reg [3:0] b_rd_ptr,
                  output reg [3:0] g_rd_ptr
                  );
    
     
        always@(posedge rclk or negedge rrst_n) begin
            if (!rrst_n) begin
                b_rd_ptr <= 4'b0000;
                g_rd_ptr <= 4'b0000;
            end
            else begin
                if (rd_enable_fifo & ~empty) begin
                    b_rd_ptr <= b_rd_ptr + 1;   
                    //ERROR: g_rd_ptr <= b_rd_ptr ^ (b_rd_ptr >> 1); ---> This will lead in g_rd_ptr always being one value behind b_rd_ptr. Analyse it clock cycle-wise starting from both 0 i.e. {b_rd_ptr, g_rd_ptr} => {0,0} => {1, (*doesn't use the new/updated b_rd_ptr here i.e. 1. Instead uses old value of it i.e. 0), 0}. Thus, out of sync.
                    g_rd_ptr <= (b_rd_ptr+1) ^ ((b_rd_ptr+1) >> 1);
                    //Now: {0,0} => {1,1} => {2,2}....
                end
            end
        end
        
        always@(*) begin
            if ( g_rd_ptr == g_wr_ptr_sync ) begin
                empty = 1'b1;
            end
            else begin
                empty = 1'b0;
            end
        end
        
endmodule
