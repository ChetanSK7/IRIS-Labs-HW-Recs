`timescale 1 ns / 1 ps

//Changes to the original given module are all included between the 2 comments given. 

module dataproc_tb;
	reg clk;
	always #5 clk = (clk === 1'b0);  //100MHz

	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;

	always @(posedge clk) begin
		reset_cnt <= reset_cnt + !resetn;
	end

	localparam ser_half_period = 50;
	event ser_sample;

	wire ser_rx = 1'b1;			
	wire ser_tx;

	wire flash_csb;
	wire flash_clk;
	wire flash_io0;
	wire flash_io1;
	wire flash_io2;
	wire flash_io3;

	/* Write your tb logic for your dataprocessing module here */
	
	// "image.hex" file generation:
	integer f, i;
    initial begin
        f = $fopen("image.hex", "w");
        for (i = 0; i < 1024; i = i + 1) begin
            $fwrite(f, "%h\n", i[7:0]); 						//produces 00, 01, 02...
        end
        $fclose(f);
    end

	//Data producer instantiation:
	wire [7:0] pixel;
    wire       valid;
    wire       ready;
	wire [7:0] pixel_out; 
    wire       valid_out;

	data_producer data_producer (
        .sensor_clk(clk),
        .rst_n(resetn),
        .ready(ready),
        .pixel(pixel),
        .valid(valid)
	);

	/*----------------------------------------------------------*/


	rvsoc_wrapper #(
		.MEM_WORDS(32768)
	) uut (
		.clk      (clk),
		.resetn   (resetn),
		.ser_rx   (ser_rx),
		.ser_tx   (ser_tx),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.flash_io2(flash_io2),
		.flash_io3(flash_io3),

		//The processor ports:
		.valid(valid),
		.pixel(pixel),
		.valid_out(valid_out),
		.ready(ready),
		.pixel_out(pixel_out) 
	);

	spiflash spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(flash_io2),
		.io3(flash_io3)
	);

	reg [7:0] buffer;

	always begin
		@(negedge ser_tx);

		repeat (ser_half_period) @(posedge clk);
		-> ser_sample;

		repeat (8) begin
			repeat (ser_half_period) @(posedge clk);
			repeat (ser_half_period) @(posedge clk);
			buffer = {ser_tx, buffer[7:1]};
			-> ser_sample;
		end

		repeat (ser_half_period) @(posedge clk);
		repeat (ser_half_period) @(posedge clk);
		-> ser_sample;
		

		if (buffer < 32 || buffer >= 127)
			$display("Serial data: %d", buffer);
		else
			$display("Serial data: '%c'", buffer);

	end

	initial begin
        $dumpfile("dataproc_tb.vcd"); // The name of the waveform file
        $dumpvars(0, dataproc_tb);    // Record everything inside this module
    end


	// NEW ADDITION: Firmware Loader (Works for BOTH Make & Vivado)
    reg [1023:0] firmware_file;
    initial begin
        // Strategy 1: If running 'make', use the filename from command line
        if ($value$plusargs("firmware=%s", firmware_file)) begin
            $readmemh(firmware_file, spiflash.memory);
        end
        
        // Strategy 2: If running Vivado, use this hardcoded path
        else begin
            // IMPORTANT: Change this path to where YOUR file actually is!
            $readmemh("C:/IRIS Labs-Hardware/IRIS-Labs-HW-Recs/Part_C/dataproc_dv/dataproc_firmware.hex", spiflash.memory);
        end
    end

endmodule

module BUFGCE (
    output O,
    input I,
    input CE
);
    // In simulation, just behave like an AND gate (Clock passes if CE is high)
    assign O = I & CE;
endmodule
