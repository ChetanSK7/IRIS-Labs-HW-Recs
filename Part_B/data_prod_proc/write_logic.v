`timescale 1ns / 1ps

module write_logic(input            wclk, 
                   input            wrst_n,
                   input            wr_enable_fifo,
                   input      [3:0] g_rd_ptr_sync,
                   output reg       full,                 
                   output reg [3:0] b_wr_ptr,
                   output reg [3:0] g_wr_ptr
                   );
      
        
        always@(posedge wclk or negedge wrst_n) begin
            if (!wrst_n) begin
                b_wr_ptr <= 4'b0000;
                g_wr_ptr <= 4'b0000;
            end
            else begin
                if (wr_enable_fifo & ~full) begin
                    b_wr_ptr <= b_wr_ptr + 1;   
                    //ERROR: g_wr_ptr <= b_wr_ptr ^ (b_wr_ptr >> 1); ---> This will lead in g_wr_ptr always being one value behind b_wr_ptr. Analyse it clock cycle-wise starting from both 0 i.e. {b_wr_ptr, g_wr_ptr} => {0,0} => {1, (*doesn't use the new/updated b_wr_ptr here i.e. 1. Instead uses old value of it i.e. 0), 0}. Thus, out of sync.
                    g_wr_ptr <= (b_wr_ptr+1) ^ ((b_wr_ptr+1) >> 1);
                    //Now: {0,0} => {1,1} => {2,2}....
                end
            end
        end
        
        always@(*) begin
            if ( {~g_wr_ptr[3:2], g_wr_ptr[1:0]} == g_rd_ptr_sync ) begin
                full = 1'b1;
            end
            else begin
                full = 1'b0;
            end
        end
        
endmodule
