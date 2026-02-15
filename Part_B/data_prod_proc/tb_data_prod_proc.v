`timescale 1ns/1ps

module tb_data_prod_proc;

    reg clk = 0;
    reg sensor_clk = 0;

    // 100MHz
    always #5 clk = ~clk;

    // 200MHz
    always #2.5 sensor_clk = ~sensor_clk;

    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;

    always @(posedge clk) begin
        if (!resetn)
            reset_cnt <= reset_cnt + 1'b1;
    end

    reg [5:0] sensor_reset_cnt = 0;
    wire sensor_resetn = &sensor_reset_cnt;

    always @(posedge sensor_clk) begin
        if (!sensor_resetn)
            sensor_reset_cnt <= sensor_reset_cnt + 1'b1;
    end

    wire [7:0] pixel;
    wire valid;
    wire ready;


	
	//Logic.
	
	//Configuration interfaces i.e. used to drive the data_proc.
    reg [4:0]   addr_in;
    reg [31:0]  wr_data_in;
    reg         write_en;
    wire [31:0] rd_data_out; //Not used but required for port

    //Output ports of data_proc.
    wire [7:0] pixel_out; 
    wire       valid_out;
    wire       ready_out; //ready signal i.e. !full.
	
	//Testcases.
	integer f, i;
    initial begin
        //Creating the image.hex file.
        f = $fopen("image.hex", "w");
        for (i = 0; i < 1024; i = i + 1) begin
            $fwrite(f, "%h\n", i[7:0]);                 //produces 00, 01, 02...
        end
        $fclose(f);

        //INitializing inputs to the data_proc.
        addr_in    = 0;
        wr_data_in = 0;
        write_en   = 0;

        //Reset timings.
        wait(resetn == 1 && sensor_resetn == 1);
        #100;

       //MODE: 00 i.e. bypass.
        $display("Testing Mode 00: Bypass");
        
        //Setting mode to 0 i.e. 00.
        @(posedge clk);
        addr_in    <= 5'h00;  //Mode register
        wr_data_in <= 32'd0;  //Value to be written in that address(Bypass)
        write_en   <= 1;
        @(posedge clk);
        write_en   <= 0;

        #2000; //Delay to let pixels flow for a while.


        //MODE: 01 i.e. invert bits.
        $display("Testing Mode 01: Invert");

        //Setting mode to 1 i.e. 01.
        @(posedge clk);
        addr_in    <= 5'h00;  //Mode register
        wr_data_in <= 32'd1;  //Value to be written in that address(Invert)
        write_en   <= 1;
        @(posedge clk);
        write_en   <= 0;

        #2000; //Delay to let pixels flow for a while.

        
        //MODE: 10 i.e. convolution.
        $display("Testing Mode 2: Convolution");

        //Setting mode to 2 i.e. 10.
        @(posedge clk);
        addr_in    <= 5'h00;
        wr_data_in <= 32'd2;
        write_en   <= 1;
        @(posedge clk);
        write_en   <= 0;

        //Loading the kernel [0 0 0; 0 1 0; 0 0 0] i.e. pixel_out = pixel_sync after a delay(time taken to fill the buffer with atleast 9 pixel_sync so as to undergo convolution)       
        //Bottom row: [0 0 0]
        @(posedge clk);
        addr_in    <= 5'h04;
        wr_data_in <= 32'h00000000;
        write_en   <= 1;
        @(posedge clk);
        write_en   <= 0;

        //Middle row: [0 1 0]
        @(posedge clk);
        addr_in    <= 5'h08;
        wr_data_in <= 32'h01000000;
        write_en   <= 1;
        @(posedge clk);
        write_en   <= 0;

        //Top row: [0 0 0]
        @(posedge clk);
        addr_in    <= 5'h0C;
        wr_data_in <= 32'h00000000;
        write_en   <= 1;
        @(posedge clk);
        write_en   <= 0;

        #5000;  //Waiting for the buffers to fill up i.e. width of the buffer = 32. As there are 2 buffers, latency = 2*32. And in the current wire, 3 more pixel_sync have to be filled, so 2*32 + 3 = 67 cycles of latency. After that every clock cycle, there will be a pixel_out produced.
        
        $display("Test Completed");
        $stop;
    end
	
	
	

    //Module instantiations.
	data_proc data_processing (
        .clk(clk),
        .rstn(resetn),
        .sensor_clk(sensor_clk),
        
        .pixel_in(pixel),
        .valid_in(valid),

        .pixel_out(pixel_out),
        .ready_out(ready),
        .valid_out(valid_out),
        
        .addr_in(addr_in),
        .wr_data_in(wr_data_in),
        .write_en(write_en),
        .rd_data_out(rd_data_out)
	);

	data_producer data_producer (
        .sensor_clk(sensor_clk),
        .rst_n(sensor_resetn),
        .ready(ready),
        .pixel(pixel),
        .valid(valid)
	);


endmodule
