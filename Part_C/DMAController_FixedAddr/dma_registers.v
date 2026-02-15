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
                     output reg [31:0] ctrl_sig_reg,    //Control signal register: Decides between read and write operation for the DMA. Bit 0: DMA is active or not. Bit 1: Read if 0, Write if 1. ++ Bit 2: inc_src_addr (Fixed address streaming modification); Bit 3: inc_dstn_addr (Fixed address streaming modification). 
                     output reg [31:0] src_addr_reg,    //Address register: Base is the starting memory address of the RAM. Every transfer leads to increment of the address by one.
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
                    case(cpu_addr[3:0])
                        4'h0: src_addr_reg  <= cpu_wr_data;
                        4'h4: count_reg     <= cpu_wr_data;
                        4'h8: ctrl_sig_reg  <= cpu_wr_data;
                        4'hc: dstn_addr_reg <= cpu_wr_data;
                        default: ;                     
                    endcase
                end
            end
        end               
        
        //Reading from the registers.
        always@(*) begin
            if (cpu_rd_en) begin
                case(cpu_addr[3:0])
                    4'h0: cpu_rd_data = src_addr_reg;
                    4'h4: cpu_rd_data = count_reg;
                    4'h8: cpu_rd_data = ctrl_sig_reg; 
                    4'hc: cpu_rd_data = dstn_addr_reg;
                    default: cpu_rd_data = 32'h0;
                endcase 
            end
            else begin
                cpu_rd_data = 32'h0;
            end
        end

endmodule
