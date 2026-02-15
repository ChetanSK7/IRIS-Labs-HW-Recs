`timescale 1ns / 1ps

module fwft_wrapper(input rclk,
                    input rrst_n,
                    input empty_fifo,           //Empty signal coming from the fifo.
                    output reg rd_enable_fifo,  //Read signal given to the fifo.
                    input [31:0] rd_data_fifo,   //Data read from fifo.
                    
                    //Ports for the user i.e. controlled by the tb.
                    output reg empty,           //Nothing left to output
                    input rd_enable,            //Whether the outputted data is to be read or not
                    output reg [31:0] rd_data   //Output wire.
                    );

        reg valid;      // Valid data held in rd_data?
        
        always@(*) begin
            rd_enable_fifo = ~empty_fifo & (~valid | rd_enable); 
            //Equivalent expression:  fifo_rd_enable = ~fifo_empty & (empty | rd_enable); 
        end
        
        always@(posedge rclk or negedge rrst_n) begin
            if (!rrst_n) begin
                valid   <= 1'b0;
                empty   <= 1'b1;
                rd_data <= 8'b0;
            end
            else begin
                if (rd_enable_fifo) begin
                    rd_data <= rd_data_fifo;
                    valid   <= 1'b1;
                    empty   <= 1'b0;
                end
                else if (rd_enable) begin
                    valid <= 1'b0;
                    empty <= 1'b1;
                end
            end
        end
        
endmodule
