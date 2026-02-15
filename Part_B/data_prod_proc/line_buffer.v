`timescale 1ns / 1ps

module line_buffer#(parameter IMAGE_SIZE = 32,              //Usually for streaming(sequential or 1D) data bursts, the image size is sqrt(total no. of bursts) so as to create a square matrix. But here it means that we have 3 fixed rows(2 buffers + current wire) but we just need to wait until the 32 columns fill up, after which continuous convolution(MAC) occurs.
                    parameter PTR_WIDTH = $clog2(IMAGE_SIZE)
                    ) 
                   (input  wire       clk,
                    input  wire       rstn,                 //Asynchronous active low reset.
                    input  wire       line_buffer_en,       //Only shift when input valid is HIGH.
                    input  wire [7:0] in_data,              //Pixel from previous row/input
                    output reg  [7:0] out_data              //Pixel delayed by IMG_WIDTH
                   );

    reg [7:0] mem [0:IMAGE_SIZE-1];     //Memory storage.
    reg [PTR_WIDTH-1:0] ptr;            //Read and write pointer.

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            ptr      <= 0;
            out_data <= 0;
        end 
        else if (line_buffer_en) begin
                out_data <= mem[ptr];       //Read from mem i.e. retrieve the pixel from exactly 1 row ago.
                mem[ptr] <= in_data;        //Write the new incoming 8 bit data burst 'pixel_sync' to the mem.
                            
                if (ptr == IMAGE_SIZE - 1)  //Since the image_size or buffer width is 32 bits, the ptr must reset to 0 once it reaches 31.
                    ptr <= 0;
                else
                    ptr <= ptr + 1;
        end
    end

endmodule
