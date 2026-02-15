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
        
        wire [31:0] ctrl_sig_reg;               //Control signal register: Decides between read and write operation for the DMA. Bit 0: DMA is active or not. Bit 1: Read if 0, Write if 1. ++ Bit 2: inc_src_addr (Fixed address streaming modification); Bit 3: inc_dstn_addr (Fixed address streaming modification). 
        wire [31:0] src_addr_reg;               //Address register: Base is the starting memory address of the RAM. Every transfer leads to increment of the address by one.
        wire [31:0] dstn_addr_reg;
        wire [31:0] count_reg;                  //Count register: Total number of data to be transferred.           
        
        wire [31:0] wr_data_fifo, rd_data_fifo; //Data coming into and going out of the FIFO respectively.
        wire full, empty;
        
        wire rx_done, tx_done;
        
        wire dma_active = ctrl_sig_reg[0];         
        //wire dma_mode   = ctrl_sig_reg[1];        //0: Read RAM and fill FIFO. 1: Write to RAM after getting data from FIFO. But here, if FIFO becomes full or empty, there is a deadlock. DMA doesn't know what to do next. Hence to automate it, We change dma_mode to auto_mode.
        
        //Switch between Read and Write modes without the CPU interfering to manually turn them on or off.
        reg auto_mode;
        always@(posedge clk or negedge reset) begin
            if (!reset) begin
                auto_mode <= 0;
            end
            else if (dma_active) begin
                if (auto_mode == 0) begin           //DMA is in READ RAM mode.
                    if (full && !rx_done) begin       
                        auto_mode <= 1;             //If FIFO is full and the DMA is still reading from the RAM (rx_done = 0), it has to stop reading and start writing to the RAM instead.
                    end
                end
                else begin                          //DMA is in WRITE RAM mode.
                    if (empty && !tx_done && !rx_done) begin       
                        auto_mode <= 0;             //If FIFO is empty and the DMA is still writing to the RAM (tx_done = 0), it has to stop writing and start reading from the RAM instead.
                    end
                end
            end
            else begin
                auto_mode <= 0;
            end
        end                          
        wire current_mode = auto_mode;
        wire [31:0] auto_ctrl_sig_reg = {ctrl_sig_reg[31:2], auto_mode,ctrl_sig_reg[0]}; 
         
                                  
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
                               .src_addr_reg(src_addr_reg),
                               .dstn_addr_reg(dstn_addr_reg),        
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
                              .ctrl_sig_reg(auto_ctrl_sig_reg),    
                              .addr_reg(src_addr_reg),        
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
                               .ctrl_sig_reg(auto_ctrl_sig_reg),    
                               .addr_reg(dstn_addr_reg),        
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
                               
        assign mem_request    = (current_mode) ?  tx_request : rx_request;       
        assign mem_addr       = (current_mode) ?  tx_addr : rx_addr;
        assign mem_wr_enable  = (current_mode) ?  tx_enable : 1'b0; 
        assign mem_rd_enable  = (!current_mode) ? rx_enable : 1'b0;       
        assign irq            = tx_done;                                         //Interrupt when WRITE is finished.
        
endmodule
