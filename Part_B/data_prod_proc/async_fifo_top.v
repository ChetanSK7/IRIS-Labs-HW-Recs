`timescale 1ns / 1ps

module async_fifo_top(input       wclk, rclk,
                      input       reset,              
                      input       wr_enable, 
                      input       rd_enable,    //Controlled by the testbench if FWFT is applied, else = rd_enable_fifo.
                      input [7:0] wr_data,
                      output      full, 
                      output      empty,        //Controlled by the testbench if FWFT is applied, else = empty_fifo.
                      output[7:0] rd_data       //Controlled by the testbench if FWFT is applied, else = rd_data_fifo.
                     );
        
        wire       wrst_n, rrst_n;
        wire       wr_enable_fifo = wr_enable & ~full;
        //wire       rd_enable_fifo = rd_enable & ~empty;  //Uncomment if FWFT isn't being applied.
        wire [3:0] b_wr_ptr, g_wr_ptr;
        wire [3:0] b_rd_ptr, g_rd_ptr;
        wire [3:0] g_wr_ptr_sync, g_rd_ptr_sync;
        
        //Internal wires of the fifo as it is wrapped by the FWFT module.
        wire       empty_fifo;
        wire       rd_enable_fifo;
        wire [7:0] rd_data_fifo;
        
        wire wclk_gated;
        BUFGCE wclk_gating_inst(.O(wclk_gated), .I(wclk), .CE(wr_enable_fifo));                         //If wr_enable = 1, wclk_gated = wclk. If 0, wclk_gated = 0 i.e. stop wclk if no write operation is happening.
        
        wire rclk_gated; 
        BUFGCE rclk_gating_inst(.O(rclk_gated), .I(rclk), .CE(rd_enable_fifo));                         //If rd_enable = 1, rclk_gated = rclk. If 0, rclk_gated = 0 i.e. stop rclk if no read operation is happening.
        
        
        reset_2ff_sync wrst_n_sync(.clk(wclk), 
                                   .rst_n_in(reset),
                                   .rst_n_out(wrst_n)
                                   );
                                   
        reset_2ff_sync rrst_n_sync(.clk(rclk), 
                                   .rst_n_in(reset),
                                   .rst_n_out(rrst_n)
                                   );
        
        /*fifo_memory fifo_mem(.wclk(wclk), .rclk(rclk), 
                             .rrst_n(rrst_n),
                             .wr_enable_fifo(wr_enable_fifo), .rd_enable_fifo(rd_enable_fifo),          //Uncomment if FWFT isn't being applied.
                             .b_wr_ptr(b_wr_ptr), .b_rd_ptr(b_rd_ptr),
                             .wr_data(wr_data),
                             .rd_data(rd_data)
                            );
        */
        
        fifo_memory fifo_mem(.wclk(wclk_gated), .rclk(rclk_gated), 
                             .rrst_n(rrst_n),
                             .wr_enable_fifo(wr_enable_fifo), .rd_enable_fifo(rd_enable_fifo),
                             .b_wr_ptr(b_wr_ptr), .b_rd_ptr(b_rd_ptr),
                             .wr_data(wr_data),
                             .rd_data(rd_data_fifo)
                            );
                            
        write_logic wr_logic(.wclk(wclk), .wrst_n(wrst_n),
                             .wr_enable_fifo(wr_enable_fifo), .g_rd_ptr_sync(g_rd_ptr_sync),
                             .full(full), .b_wr_ptr(b_wr_ptr), .g_wr_ptr(g_wr_ptr)
                             );
                             
        /*read_logic rd_logic(.rclk(rclk), .rrst_n(rrst_n),
                             .rd_enable_fifo(rd_enable_fifo), .g_wr_ptr_sync(g_wr_ptr_sync),            //Uncomment if FWFT isn't being applied.
                             .empty(empty), .b_rd_ptr(b_rd_ptr), .g_rd_ptr(g_rd_ptr)
                             ); 
        */   
        
        read_logic rd_logic(.rclk(rclk), .rrst_n(rrst_n),
                             .rd_enable_fifo(rd_enable_fifo), .g_wr_ptr_sync(g_wr_ptr_sync),
                             .empty(empty_fifo), .b_rd_ptr(b_rd_ptr), .g_rd_ptr(g_rd_ptr)
                             ); 
                             
        ptr_2ff_sync w_ptr_sync(.clk(rclk), .rst_n(rrst_n),
                                .g_ptr(g_wr_ptr), .g_ptr_sync(g_wr_ptr_sync)
                                );   
                             
        ptr_2ff_sync r_ptr_sync(.clk(wclk), .rst_n(wrst_n),
                                .g_ptr(g_rd_ptr), .g_ptr_sync(g_rd_ptr_sync)
                                );
                                
        fwft_wrapper fwft_logic(.rclk(rclk),
                                .rrst_n(rrst_n),
                                .empty_fifo(empty_fifo),            //Empty signal coming from the fifo.
                                .rd_enable_fifo(rd_enable_fifo),    //Read signal given to the fifo.
                                .rd_data_fifo(rd_data_fifo),        //Data read from fifo.
                    
                                //Ports for the user i.e. controlled by the tb.
                                .empty(empty),                      //Nothing left to output
                                .rd_enable(rd_enable),              //Whether the outputted data is to be read or not
                                .rd_data(rd_data)                   //Output wire.
                                );
        
endmodule