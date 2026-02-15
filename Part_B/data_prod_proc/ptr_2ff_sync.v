`timescale 1ns / 1ps

module ptr_2ff_sync(input            clk,
                    input            rst_n,
                    input      [3:0] g_ptr,
                    output reg [3:0] g_ptr_sync
                    );

        reg [3:0] q1;        //Output after the first flip flop in the 2 flop synchronizer.
        
        always@(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                q1 <= 0;
                g_ptr_sync <= 0;
            end
            else begin
                q1 <= g_ptr;
                g_ptr_sync <= q1;            
            end
        end      
endmodule
