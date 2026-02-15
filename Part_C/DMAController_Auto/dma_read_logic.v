`timescale 1ns / 1ps

module dma_read_logic(input clk,
                      input reset,
                      
                      //DMA Registers.
                      input [31:0] ctrl_sig_reg,    //Control signal register: Decides between read and write operation for the DMA. Bit 0: DMA is active or not. Bit 1: Read if 0, Write if 1.
                      input [31:0] addr_reg,        //Address register: Base is the starting memory address of the RAM. Every transfer leads to increment of the address by one.
                      input [31:0] count_reg,       //Count register: Total number of data to be transferred. 
                      
                      //Arbiter & RAM. (Source to the DMA)
                      output reg        mem_request,     //Request to the arbiter by the DMA to take control over the bus.
                      input             mem_grant,       //Request granted by the arbiter to the DMA to take control over the bus.                     
                      output reg [31:0] mem_addr,        //Address in the RAM that the DMA wants to read from.
                      output reg        rx_enable,       //If 1, DMA reads the data given by the RAM, which is on the bus.
                      input      [31:0] mem_rd_data,     //The data transferred from RAM to the DMA.
                      
                      //FIFO ports. (Destination of the DMA)
                      input             full,            //FIFO filled completely. DMA should stop sending more data. A enable signal can be used i.e. DMA's wr_enable = !full.
                      output reg        wr_enable,       //If 1, writes the data from the RAM into the FIFO.
                      output reg [31:0] wr_data,         //The data to be written into the FIFO.
                      
                      //Interrupt - Usually sent to the CPU to notify that data transfer is done and it can take over the bus control.
                      output reg        rx_done          //Flag to indicate data transfer is done.                     
                      );

        wire dma_active = ctrl_sig_reg[0];               //If 1, DMA is active.
        wire dma_mode   = ctrl_sig_reg[1];               //0: Read; 1: Write.
        
        localparam IDLE = 0, BUS_REQ = 1, READ_DATA = 2, DONE = 3;
        
        reg [1:0] state, next_state;
        reg [31:0] current_addr, current_count;
        
        always@(posedge clk or negedge reset) begin
            if(!reset) begin
                state         <= IDLE;
                rx_done       <= 0;
                current_addr  <= 0;
                current_count <= 0;
            end
            else begin
                state <= next_state;
                
                if (state == IDLE) begin
                    if (dma_active && !dma_mode) begin
                        current_addr  <= addr_reg;
                        current_count <= count_reg;
                        rx_done <= 0;
                    end
                end
                else if (state == READ_DATA) begin
                    if (mem_grant && !full) begin
                        current_addr <= current_addr + 4;
                        current_count <= current_count - 1;
                    end
                end
                else if (state == DONE) begin
                    rx_done <= 1'b1;
                end
            end
        end
        
        always@(*) begin
        
            next_state  = state;
            mem_request = 1'b0;
            mem_addr    = 32'b0;
            rx_enable   = 1'b0;
            wr_enable   = 1'b0;
            wr_data     = 32'b0;
            
            case(state)
                IDLE: next_state = (dma_active && !dma_mode) ? BUS_REQ : IDLE;
                
                BUS_REQ:   begin
                               mem_request = 1'b1;
                               next_state  = (mem_grant && !full) ? READ_DATA : BUS_REQ;
                           end
                         
                READ_DATA: begin
                               mem_request = 1'b1;
                               mem_addr    = current_addr;
                               rx_enable   = 1'b1;
                               
                               wr_enable = (mem_grant && !full) ? 1'b1 : 1'b0;
                               wr_data   = (mem_grant && !full) ? mem_rd_data : 1'b0;
                               next_state= (mem_grant && !full) ? ((current_count == 1) ? DONE: READ_DATA) : READ_DATA;       //Burst mode. current_count is set to 1 as it is calculated dequentially i.e. it becomes 0 in the next cycle and instantly goes to DONE state.
                               //next_state= (mem_grant && !full) ? ((current_count == 1) ? DONE: BUS_REQ) : READ_DATA;       //Cycle stealing mode.
                           end
                           
                DONE:      begin
                               next_state = IDLE;
                           end
            endcase
        end
endmodule
