`timescale 1ns / 1ps

module dma_controller_top_tb();

          //Signals.
          reg clk;
          reg reset;
                          
          reg             cpu_wr_en;       //Write enable of the CPU.
          reg             cpu_rd_en;       //Read enable of the CPU.
          reg      [31:0] cpu_addr;        //Address bus of the CPU. Decides which register to write to. Used in register mapping of the DMA registers.
          reg      [31:0] cpu_wr_data;     //Data to be written by the CPU to the DMA registers.
          wire     [31:0] cpu_rd_data;     //Data to be written to the CPU by the DMA registers.
                          
          wire            mem_request;
          reg             mem_grant;
          wire     [31:0] mem_addr;
          reg      [31:0] mem_rdata;       //Data read from RAM.
          wire     [31:0] mem_wdata;       //Data written to RAM.
          wire            mem_wr_enable;
          wire            mem_rd_enable;
                       
          wire            irq;             //Interrupt request i.e. (rx_done || tx_done)
          
          
          //RAM
          reg [31:0] RAM [0:1023]; 
          integer i;   
          
          dma_controller_top dut (.clk(clk), 
                                  .reset(reset),
                                  .cpu_wr_en(cpu_wr_en), 
                                  .cpu_rd_en(cpu_rd_en),
                                  .cpu_addr(cpu_addr), 
                                  .cpu_wr_data(cpu_wr_data), 
                                  .cpu_rd_data(cpu_rd_data),
                                  .mem_request(mem_request), 
                                  .mem_grant(mem_grant),
                                  .mem_addr(mem_addr), 
                                  .mem_rdata(mem_rdata), 
                                  .mem_wdata(mem_wdata),
                                  .mem_wr_enable(mem_wr_enable), 
                                  .mem_rd_enable(mem_rd_enable),
                                  .irq(irq)
                                  ); 
                                  
           
           initial clk = 0;
           always #5 clk = ~clk; //100MHz (10ns period)  
           
           
           task cpu_write(input [31:0] addr, input [31:0] data);
                begin
                    @(posedge clk);
                    cpu_wr_en   = 1;
                    cpu_addr    = addr;
                    cpu_wr_data = data;
                    @(posedge clk);
                    cpu_wr_en   = 0;
                    cpu_addr    = 0;
                    cpu_wr_data = 0;
                end
            endtask     
            
            initial begin
               
                reset = 0;
                cpu_wr_en = 0; cpu_rd_en = 0;
                mem_grant = 0;
                
                for (i=0; i<1024; i=i+1) begin
                    RAM[i] = 32'hA0000000 + i; 
                end

                for (i=32; i<48; i=i+1) begin
                    RAM[i] = 32'hDEAD_BEEF; 
                end
                
                #20 reset = 1; 
        
                // -----------------------------------------------------
                // STEP 1: Configure DMA for READ (Source -> FIFO)
                // -----------------------------------------------------
                $display("[TIME %0t] Configuring DMA for READ Operation...", $time);
                
                // 1. Set Address (Source = 0x0)
                // Note: RAM index 0 corresponds to address 0x0
                cpu_write(32'h00, 32'h0000_0000); 
                
                // 2. Set Count (Transfer 10 words)
                cpu_write(32'h04, 32'd4);
                
                // 3. Start DMA (Control Reg: Start=1, Mode=0 Read)
                cpu_write(32'h08, 32'h0000_0001); 
        
                // Wait for IRQ (Data moved to FIFO)
                wait(irq);
                @(posedge clk);
                
                $display("[TIME %0t] READ Operation Complete (IRQ Received).", $time);
                
                // Clear the Start Bit (CPU acknowledges IRQ)
                cpu_write(32'h08, 32'h0000_0000); 
                #50;
        
                // -----------------------------------------------------
                // STEP 2: Configure DMA for WRITE (FIFO -> Destination)
                // -----------------------------------------------------
                $display("[TIME %0t] Configuring DMA for WRITE Operation...", $time);
        
                // 1. Set Address (Destination = 0x20, which is index 32 in 32-bit RAM)
                // 0x20 bytes = 32 decimal. Since RAM is [31:0], address index is 8? 
                // Wait, let's assume byte addressing logic in RAM model below.
                // For simplicity, let's say mem_addr corresponds to word index directly.
                cpu_write(32'h00, 32'd32); 
                
                // 2. Set Count (Transfer 10 words)
                cpu_write(32'h04, 32'd4);
                
                // 3. Start DMA (Control Reg: Start=1, Mode=1 Write)
                cpu_write(32'h08, 32'h0000_0003); // Bit 0=1, Bit 1=1
        
                // Wait for IRQ (Data moved from FIFO to RAM)
                wait(irq);
                @(posedge clk);
                
                $display("[TIME %0t] WRITE Operation Complete (IRQ Received).", $time);
                
                // Clear Control
                cpu_write(32'h08, 32'h0000_0000); 
                #50;
        
                // -----------------------------------------------------
                // STEP 3: Verification (Did the data move?)
                // -----------------------------------------------------
                $display("--- VERIFICATION ---");
                for (i=0; i<4; i=i+1) begin
                    if (RAM[32+i] == i) 
                        $display("Addr %0d: Expected %0d, Got %0d -- PASS", 32+i, i, RAM[32+i]);
                    else
                        $display("Addr %0d: Expected %0d, Got %0d -- FAIL", 32+i, i, RAM[32+i]);
                end
                
                $finish;
            end 
            
            
            always @(*) begin
                if (mem_rd_enable) 
                    mem_rdata = RAM[mem_addr]; 
                else 
                    mem_rdata = 32'b0;
            end
        
            // Handling Writes & Grant (Keep this Sequential)
            always @(posedge clk) begin
                // Default Grant
                mem_grant <= 0;
        
                if (mem_request) begin
                    mem_grant <= 1; 
                    
                    // Handle Writes (Must be on clock edge)
                    if (mem_wr_enable) begin
                        RAM[mem_addr] <= mem_wdata;
                        $display("[RAM WRITE] Addr: %0d, Data: %0d", mem_addr, mem_wdata);
                    end
                end
            end
endmodule
