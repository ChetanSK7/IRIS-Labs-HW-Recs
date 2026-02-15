`timescale 1ns / 1ps

//We use 'asynchronous' active low reset everywhere. This would mean that the CDC is involved and hence these resets from the external sources, like FPGA board for example, have to be synchronized for the particular clock domains.
module reset_2ff_sync(input      clk,
                      input      rst_n_in,
                      output reg rst_n_out
                      );
                      
        reg rst_n_q1;       //Output of the first flop of the 2 flop synchronizer.   
        
        always@(posedge clk or negedge rst_n_in) begin
            if (!rst_n_in) begin
                rst_n_q1  <= 1'b0;
                rst_n_out <= 1'b0;
            end
            else begin
                rst_n_q1  <= 1'b1;
                rst_n_out <= rst_n_q1;
            end
        end              
endmodule
