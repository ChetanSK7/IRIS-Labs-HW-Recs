`timescale 1ns / 1ps

module dma_registers(input             clk,             //Clock signal.
                     input             reset,           //Asynchronous active low reset.
                     
                     //CPU Ports.
                     input             cpu_wr_en,       //Write enable of the CPU.
                     input             cpu_rd_en,       //Read enable of the CPU.
                     input      [31:0] cpu_addr,        //Address bus of the CPU. Decides which register to write to. Used in register mapping of the DMA registers.
                     input      [31:0] cpu_wr_data,     //Data to be written by the CPU to the DMA registers.
                     output reg [31:0] cpu_rd_data,     //Data to be written to the CPU by the DMA registers.
                     
                     //DMA Registers.
                     output reg [31:0] ctrl_sig_reg,    //Control signal register: Decides between read and write operation for the DMA. Bit 0: DMA is active or not. Bit 1: Read if 0, Write if 1.
                     output reg [31:0] src_addr_reg,        //Address register: Base is the starting memory address of the RAM. Every transfer leads to increment of the address by one.
                     output reg [31:0] dstn_addr_reg,
                     output reg [31:0] count_reg        //Count register: Total number of data to be transferred.                     
                     );
        
        //Configuring the DMA registers. 
        
        //Writing to the registers.
        always@(posedge clk or negedge reset) begin
            if (!reset) begin
                ctrl_sig_reg  <= 0;
                src_addr_reg  <= 0;
                dstn_addr_reg <= 0;
                count_reg     <= 0;
            end
            else begin
                if (cpu_wr_en) begin
                    case(cpu_addr)
                        32'h00: src_addr_reg  <= cpu_wr_data;
                        32'h04: count_reg     <= cpu_wr_data;
                        32'h08: ctrl_sig_reg  <= cpu_wr_data;
                        32'h0c: dstn_addr_reg <= cpu_wr_data;
                        default: ;                     
                    endcase
                end
            end
        end               
        
        //Reading from the registers.
        always@(*) begin
            if (cpu_rd_en) begin
                case(cpu_addr)
                    32'h00: cpu_rd_data = src_addr_reg;
                    32'h04: cpu_rd_data = count_reg;
                    32'h08: cpu_rd_data = ctrl_sig_reg; 
                    32'h0c: cpu_rd_data = dstn_addr_reg;
                    default: cpu_rd_data = 32'h0;
                endcase 
            end
            else begin
                cpu_rd_data = 32'h0;
            end
        end

endmodule
