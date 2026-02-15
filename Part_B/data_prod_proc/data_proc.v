`timescale 1ns/1ps

module data_proc (//Clock and reset inputs.
                  input clk,                       // proc's clock.
                  input rstn,                      // proc's reset.
                  input sensor_clk,                // prod's clock.
                  
                  //Signals coming from data_prod.
                  input      [7:0] pixel_in,       // prod : pixel.
                  input            valid_in,       // prod : valid.
                  
                  //Outputs of data_proc.
                  output reg [7:0] pixel_out,      //The final output after certain operations based on the mode values.
                  output           ready_out,      //not_full.     
                  output reg       valid_out,      //not_empty (or) rd_enable of the async_fifo_top.
                  
                  //Ports for register mapping and address decoding.
                  input [4:0]       addr_in,           //Acts as a pointer; indicates the memory address to which the data has to be written to or read from. It is of 5 bits because our addresses stop at 0x10 i.e. 0001 0000 (16). Thus the higher power of 2 is to be chosen i.e. 32 (2 power 5). Thus 5 bits.
                  input [31:0]      wr_data_in,        //Data to be written in the address pointed by the addr_in.
                  input             write_en,          //addr_in just points at the address. But the action happens when this enable goes high.
                  output reg [31:0] rd_data_out        //Data to be read from the address pointed by the addr_in.
                  );
                  
                  
                  //Memory mapping.
                  
                  /* --------------------------------------------------------------------------
                  Memory map of registers:
                  0x00 - Mode (2 bits)    [R/W]
                  0x04 - Kernel (9 * 8 = 72 bits)     [R/W]
                  0x10 - Status reg   [R]
                  ----------------------------------------------------------------------------*/
                  
                  reg [1:0] mode_reg;                  //2-bit control signal that decides what operation to perform on the pixel_sync.
                  reg [71:0] kernel_reg;               //9 bytes (3x3 array with 8 bits storage per element of the array).
                  
                          //Write logic.
                          always@(posedge clk or negedge rstn) begin
                            if (!rstn) begin
                                mode_reg    <= 0;
                                kernel_reg  <= 72'h000000000100000000;
                            end
                            else begin
                                if (write_en) begin
                                    case(addr_in)
                                        5'h00: mode_reg <= wr_data_in[1:0];
                                        5'h04: kernel_reg[31:0]   <= wr_data_in;
                                        5'h08: kernel_reg[63:32]  <= wr_data_in;
                                        5'h0c: kernel_reg [71:64] <= wr_data_in[7:0];
                                    endcase
                                end
                            end
                          end
                          
                          //Read logic.
                          always@(*) begin
                            case(addr_in)
                                5'h00: rd_data_out <= {32'b0,mode_reg};
                                5'h04: rd_data_out <= kernel_reg[31:0];
                                5'h08: rd_data_out <= kernel_reg[63:32];
                                5'h0c: rd_data_out <= {24'b0, kernel_reg[7:0]};

                                //Handle completion using status registers: Updating the status registers to memory map valid_out and pixel_out, which were previously just wires in the testbench.
                                //5'h10: rd_data_out <= 32'b0;                //status_reg
                                5'h10: rd_data_out <= {31'b0, valid_out};
                                5'h14: rd_data_out <= {24'b0, pixel_out};

                                default: rd_data_out <= 32'b0;    
                            endcase
                          end                 
                  
                  
                
                
                
                  //Instantiating the async_fifo_top.
                  wire       fifo_full;                     //Wire to indicate full flag.
                  wire       fifo_empty;                    //Wire to indicate empty flag.
                  wire [7:0] pixel_sync;                    //The output of the async_fifo_top which is ready to undergo certain operations.
                  wire       fifo_rd_enable;                //Wire to indicate rd_enable of the async_fifo_top
                
                  assign ready_out = !fifo_full;            //Tell data_prod to stop if FIFO is full.
                  assign fifo_rd_enable = !fifo_empty;      //Read immediately if data is available.
                
                  async_fifo_top u_fifo (.wclk(sensor_clk),
                                         .rclk(clk),
                                         .reset (rstn),     //Asynchronous active low reset. Not correct as reset domain crossing is to be considered. I'll try to correct it somehow hmmm.
                                         .wr_enable(valid_in),
                                         .rd_enable(fifo_rd_enable),
                                         .wr_data(pixel_in),
                                         .full(fifo_full),
                                         .empty(fifo_empty),
                                         .rd_data(pixel_sync)
                                         );
                    
                    
                    
                    
                  //Instantiating the line buffers. Lets say, pixel_sync from the fifo comes this way:  ..kjihgfedcba, each letter representing pixel_sync. Since our image_size i.e. buffer width is 32, the first 32 LSBs go to buffer_1, next 32 LSBs go to buffer_0. Since convolution using 3x3 kernel is needed, we should also wait for 3 inputs to arrive. Thus, 'a' will be the first out_data.
                  wire [7:0] buffer0_out;
                  wire [7:0] buffer1_out;
                  
                  line_buffer buffer_0 (.clk(clk),
                                        .rstn(rstn),
                                        .line_buffer_en(fifo_rd_enable),    //Obviously all this process only if the data is being read from the fifo.
                                        .in_data(pixel_sync),
                                        .out_data(buffer0_out)
                                       );
                                       
                  line_buffer buffer_1 (.clk(clk),
                                        .rstn(rstn),
                                        .line_buffer_en(fifo_rd_enable),    //Obviously all this process only if the data is being read from the fifo.
                                        .in_data(buffer0_out),
                                        .out_data(buffer1_out)
                                       );
                  
                  
                  
                  
                  
                  //Cyclic shifting of the elements within the buffers after every convolution.
                  reg [7:0] w0_d1, w0_d2;  //buffer_1
                  reg [7:0] w1_d1, w1_d2;  //buffer_0 
                  reg [7:0] w2_d1, w2_d2;  //Current wire i.e. pixel_sync enters the 1st block. Rest all shift to the right.
                
                  always @(posedge clk) begin
                      if (fifo_rd_enable) begin
                          w0_d1 <= buffer1_out; w0_d2 <= w0_d1;
                          w1_d1 <= buffer0_out; w1_d2 <= w1_d1;
                          w2_d1 <= pixel_sync; w2_d2 <= w2_d1;
                      end
                  end
                  
                  
                  
                  
                  
                  //Convolution logic.
                  //Kernel
                  wire signed [7:0] k0=kernel_reg[7:0];     wire signed [7:0] k1=kernel_reg[15:8];      wire signed [7:0] k2=kernel_reg[23:16];
                  wire signed [7:0] k3=kernel_reg[31:24];   wire signed [7:0] k4=kernel_reg[39:32];     wire signed [7:0] k5=kernel_reg[47:40];
                  wire signed [7:0] k6=kernel_reg[55:48];   wire signed [7:0] k7=kernel_reg[63:56];     wire signed [7:0] k8=kernel_reg[71:64];
                  
                  //Streaming data window.
                  wire signed [9:0] p0={2'b0, w0_d2};       wire signed [9:0] p1={2'b0, w0_d1};         wire signed [9:0] p2={2'b0, buffer1_out};
                  wire signed [9:0] p3={2'b0, w1_d2};       wire signed [9:0] p4={2'b0, w1_d1};         wire signed [9:0] p5={2'b0, buffer0_out};
                  wire signed [9:0] p6={2'b0, w2_d2};       wire signed [9:0] p7={2'b0, w2_d1};         wire signed [9:0] p8={2'b0, pixel_sync};
                  
                  //Multiply:   Imagine that kernel is a stencil and the shift registers in which the new data is getting updated every cycle is a window over it. Every cycle, a MAC operation occurs
                  wire signed [19:0] m0 = p0 * k0;          wire signed [19:0] m1 = p1 * k1;            wire signed [19:0] m2 = p2 * k2;
                  wire signed [19:0] m3 = p3 * k3;          wire signed [19:0] m4 = p4 * k4;            wire signed [19:0] m5 = p5 * k5;
                  wire signed [19:0] m6 = p6 * k6;          wire signed [19:0] m7 = p7 * k7;            wire signed [19:0] m8 = p8 * k8;
                  
                  //Accumulate:
                  wire signed [19:0] sum = m0 + m1 + m2 + m3 + m4 + m5 + m6 + m7 + m8; 
                  
                  //Logic to reduce the obtained output to a 8 bit output.
                  wire [7:0] conv_result; 
                  assign conv_result = sum[19] ? 8'h0 : (sum > 20'd255 ? 8'd255 : sum[7:0]);




                  
                 //Output MUX that decides the pixel_out based on results obtained at the end of each operation, governed by the control signal: mode.
                  
                 /* --------------------------------------------------------------------------
                 Purpose of this module : This module should perform certain operations
                 based on the mode register and pixel values streamed out by data_prod module.
                
                 mode[1:0]:
                 00 - Bypass
                 01 - Invert the pixel
                 10 - Convolution with a kernel of your choice (kernel is 3x3 2d array)
                 11 - Not implemented
                 ----------------------------------------------------------------------------*/
                 
                 always@(posedge clk or negedge rstn) begin
                   if (!rstn) begin
                       pixel_out <= 0;
                       valid_out <= 0;
                   end
                   else begin
                       valid_out <= fifo_rd_enable;
                       case(mode_reg)
                           2'b00: pixel_out <= pixel_sync;      //No operation done on the output (rd_data) of the fifo.
                           2'b01: pixel_out <= ~(pixel_sync);   //Each bit of the fifo's output is inverted.
                           2'b10: pixel_out <= conv_result;
                           default: pixel_out <= 8'b0;                        
                       endcase
                   end
                 end               
                 
endmodule