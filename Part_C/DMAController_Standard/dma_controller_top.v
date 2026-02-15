`timescale 1ns / 1ps


module dma_controller_top(input clk,
                          input reset,
                          
                          input             cpu_wr_en,       //Write enable of the CPU.
                          input             cpu_rd_en,       //Read enable of the CPU.
                          input      [31:0] cpu_addr,        //Address bus of the CPU. Decides which register to write to. Used in register mapping of the DMA registers.
                          input      [31:0] cpu_wr_data,     //Data to be written by the CPU to the DMA registers.
                          output     [31:0] cpu_rd_data,     //Data to be written to the CPU by the DMA registers.
                          
                          output        mem_request,
                          input         mem_grant,
                          output [31:0] mem_addr,
                          input [31:0]  mem_rdata,           //Data read from RAM.
                          output [31:0] mem_wdata,           //Data written to RAM.
                          output        mem_wr_enable,
                          output        mem_rd_enable,
                       
                          output irq                         //Interrupt request i.e. (rx_done || tx_done)
                          );
        
        wire wr_enable, rd_enable;
        
        wire rx_request, tx_request;
        wire [31:0] rx_addr, tx_addr;
        wire rx_enable, tx_enable;       
        
        wire [31:0] ctrl_sig_reg;               //Control signal register: Decides between read and write operation for the DMA. Bit 0: DMA is active or not. Bit 1: Read if 0, Write if 1.
        wire [31:0] addr_reg;                   //Address register: Base is the starting memory address of the RAM. Every transfer leads to increment of the address by one.
        wire [31:0] count_reg;                  //Count register: Total number of data to be transferred.           
        
        wire [31:0] wr_data_fifo, rd_data_fifo; //Data coming into and going out of the FIFO respectively.
        wire full, empty;
        
        wire dma_active = ctrl_sig_reg[0];         
        wire dma_mode   = ctrl_sig_reg[1];  
        
        wire rx_done, tx_done;
                          
        dma_registers dma_regs(.clk(clk),             
                               .reset(reset),           
                     
                               //CPU Ports.
                               .cpu_wr_en(cpu_wr_en),       
                               .cpu_rd_en(cpu_rd_en),       
                               .cpu_addr(cpu_addr),        
                               .cpu_wr_data(cpu_wr_data),     
                               .cpu_rd_data(cpu_rd_data),     
                             
                               //DMA Registers.
                               .ctrl_sig_reg(ctrl_sig_reg),    
                               .addr_reg(addr_reg),        
                               .count_reg(count_reg)                            
                               );
                               
                               
        async_fifo_top async_fifo(.wclk(clk), .rclk(clk),
                                  .reset(reset),              
                                  .wr_enable(wr_enable), 
                                  .rd_enable(rd_enable),    
                                  .wr_data(wr_data_fifo),
                                  .full(full), 
                                  .empty(empty),            
                                  .rd_data(rd_data_fifo)         
                                  );
                                  
                                  
        dma_read_logic dma_rx(.clk(clk),
                              .reset(reset),
                               
                              //DMA Registers.
                              .ctrl_sig_reg(ctrl_sig_reg),    
                              .addr_reg(addr_reg),        
                              .count_reg(count_reg),                              
                              
                              //RAM & Arbiter ports.
                              .mem_request(rx_request),
                              .mem_grant(mem_grant),
                              .mem_addr(rx_addr),
                              .rx_enable(rx_enable),
                              .mem_rd_data(mem_rdata),
                              
                              .full(full),
                              .wr_enable(wr_enable),
                              .wr_data(wr_data_fifo),
                              
                              .rx_done(rx_done)
                              );
                              
                              
        dma_write_logic dma_tx(.clk(clk),
                               .reset(reset),
                               
                               //DMA Registers.
                               .ctrl_sig_reg(ctrl_sig_reg),    
                               .addr_reg(addr_reg),        
                               .count_reg(count_reg),                              
                              
                               //RAM & Arbiter ports.
                               .mem_request(tx_request),
                               .mem_grant(mem_grant),
                               .mem_addr(tx_addr),
                               .tx_enable(tx_enable),
                               .mem_wr_data(mem_wdata),
                              
                               .empty(empty),
                               .rd_enable(rd_enable),
                               .rd_data(rd_data_fifo),
                              
                               .tx_done(tx_done)
                               ); 
                               
        assign mem_request    = (dma_mode) ? tx_request : rx_request;       
        assign mem_addr       = (dma_mode) ? tx_addr : rx_addr;
        assign mem_wr_enable  = (dma_mode) ? tx_enable : 1'b0; 
        assign mem_rd_enable  = (!dma_mode) ? rx_enable : 1'b0;       
        assign irq            = rx_done | tx_done;
        
endmodule
