`timescale 1ns/1ps

module data_producer #(
    parameter IMAGE_SIZE = 1024
)(
    input sensor_clk,
    input rst_n,
    input ready,
    output reg [7:0] pixel,
    output reg valid
);

    reg [7:0] image_mem [0:IMAGE_SIZE-1];
    reg [$clog2(IMAGE_SIZE):0] pixel_index;

    initial begin
        $readmemh("image.hex", image_mem);
    end

    always @(posedge sensor_clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_index <= 0;
            valid       <= 0;
            pixel       <= 8'h00;
        end else begin
            if (ready) begin
                pixel <= image_mem[pixel_index];
                valid <= 1'b1;

                if (pixel_index < IMAGE_SIZE-1)
                    pixel_index <= pixel_index + 1;
                else
                    pixel_index <= 0;
            end else begin
                valid <= (pixel_index == 0) ? 1'b0 : 1'b1;
            end
        end
    end

endmodule
