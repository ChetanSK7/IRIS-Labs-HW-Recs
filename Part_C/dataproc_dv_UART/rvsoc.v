//Changes to the original given module are all followed by comments explaining the changes. 

module rvsoc (
	input clk,
	input resetn,

	output        iomem_valid,
	input         iomem_ready,
	output [ 3:0] iomem_wstrb,
	output [31:0] iomem_addr,
	output [31:0] iomem_wdata,
	input  [31:0] iomem_rdata,

	input  irq_5,
	input  irq_6,
	input  irq_7,

	output ser_tx,
	input  ser_rx,

	output flash_csb,
	output flash_clk,

	output flash_io0_oe,
	output flash_io1_oe,
	output flash_io2_oe,
	output flash_io3_oe,

	output flash_io0_do,
	output flash_io1_do,
	output flash_io2_do,
	output flash_io3_do,

	input  flash_io0_di,
	input  flash_io1_di,
	input  flash_io2_di,
	input  flash_io3_di,

	//Processor ports. (Testbench will need them as SoC pins to drive them)
	input        valid,
	input  [7:0] pixel,
	output       valid_out,
    output       ready,
	output [7:0] pixel_out 
);
	parameter [0:0] BARREL_SHIFTER = 1;
	parameter [0:0] ENABLE_MUL = 1;
	parameter [0:0] ENABLE_DIV = 1;
	parameter [0:0] ENABLE_FAST_MUL = 0;
	parameter [0:0] ENABLE_COMPRESSED = 1;
	parameter [0:0] ENABLE_COUNTERS = 1;
	parameter [0:0] ENABLE_IRQ_QREGS = 0;

	parameter integer MEM_WORDS = 256;
	parameter [31:0] STACKADDR = (4*MEM_WORDS);
	parameter [31:0] PROGADDR_RESET = 32'h 0010_0000;
	parameter [31:0] PROGADDR_IRQ = 32'h 0000_0000;

	reg [31:0] irq;
	wire irq_stall = 0;
	wire irq_uart = 0;

	always @* begin
		irq = 0;
		irq[3] = irq_stall;
		irq[4] = irq_uart;
		irq[5] = irq_5;
		irq[6] = irq_6;
		irq[7] = irq_7;
	end

	wire mem_valid;
	wire mem_instr;
	wire mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	wire [31:0] mem_rdata;

	wire spimem_ready;
	wire [31:0] spimem_rdata;

	reg ram_ready;
	wire [31:0] ram_rdata;

	//ready and rdata for proc are definedd along with its sel and output data carried back to the CPU i.e. the _do signals.
 
	assign iomem_valid = mem_valid && (mem_addr[31:24] > 8'h 01);
	assign iomem_wstrb = mem_wstrb;
	assign iomem_addr = mem_addr;
	assign iomem_wdata = mem_wdata;

	wire spimemio_cfgreg_sel = mem_valid && (mem_addr == 32'h 0200_0000);
	wire [31:0] spimemio_cfgreg_do;

	wire        simpleuart_reg_div_sel = mem_valid && (mem_addr == 32'h 0200_0004);
	wire [31:0] simpleuart_reg_div_do;

	wire        simpleuart_reg_dat_sel = mem_valid && (mem_addr == 32'h 0200_0008);
	wire [31:0] simpleuart_reg_dat_do;
	wire        simpleuart_reg_dat_wait;

	
	wire        proc_sel = mem_valid && (mem_addr[31:24] == 8'h04);   //Enables our proc module whenever address starts like 0x04...
    wire [31:0] proc_do;									          //Output from the processor that goes back to the CPU.
	wire        proc_ready = proc_sel;							      //The proc is ready whenever selected.
	

	assign mem_ready =
    (iomem_valid && iomem_ready) ||
    spimem_ready ||
    ram_ready ||
    spimemio_cfgreg_sel ||
    simpleuart_reg_div_sel ||
    (simpleuart_reg_dat_sel && !simpleuart_reg_dat_wait) ||
	(proc_ready);                                                    //Updated to include processor's acknowledge signal.

	assign mem_rdata =
    (iomem_valid && iomem_ready) ? iomem_rdata :
    spimem_ready                ? spimem_rdata :
    ram_ready                   ? ram_rdata :
    spimemio_cfgreg_sel         ? spimemio_cfgreg_do :
    simpleuart_reg_div_sel      ? simpleuart_reg_div_do :
    simpleuart_reg_dat_sel      ? simpleuart_reg_dat_do :
	proc_sel                    ? proc_do :					         //mem_rdata updated to include processor's logic for deciding mem_rdata.
    32'h0;													         //READ MUX

	picorv32 #(
		.STACKADDR(STACKADDR),
		.PROGADDR_RESET(PROGADDR_RESET),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.BARREL_SHIFTER(BARREL_SHIFTER),
		.COMPRESSED_ISA(ENABLE_COMPRESSED),
		.ENABLE_COUNTERS(ENABLE_COUNTERS),
		.ENABLE_MUL(ENABLE_MUL),
		.ENABLE_DIV(ENABLE_DIV),
		.ENABLE_FAST_MUL(ENABLE_FAST_MUL),
		.ENABLE_IRQ(1),
		.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS)
	) cpu (
		.clk         (clk),
		.resetn      (resetn),
		.mem_valid   (mem_valid),
		.mem_instr   (mem_instr),
		.mem_ready   (mem_ready),
		.mem_addr    (mem_addr),
		.mem_wdata   (mem_wdata),
		.mem_wstrb   (mem_wstrb),
		.mem_rdata   (mem_rdata),
		.irq         (irq)
	);

	spimemio spimemio (
		.clk    (clk),
		.resetn (resetn),
		.valid  (mem_valid && mem_addr >= 4*MEM_WORDS && mem_addr < 32'h 0200_0000),
		.ready  (spimem_ready),
		.addr   (mem_addr[23:0]),
		.rdata  (spimem_rdata),

		.flash_csb    (flash_csb),
		.flash_clk    (flash_clk),

		.flash_io0_oe (flash_io0_oe),
		.flash_io1_oe (flash_io1_oe),
		.flash_io2_oe (flash_io2_oe),
		.flash_io3_oe (flash_io3_oe),

		.flash_io0_do (flash_io0_do),
		.flash_io1_do (flash_io1_do),
		.flash_io2_do (flash_io2_do),
		.flash_io3_do (flash_io3_do),

		.flash_io0_di (flash_io0_di),
		.flash_io1_di (flash_io1_di),
		.flash_io2_di (flash_io2_di),
		.flash_io3_di (flash_io3_di),

		.cfgreg_we(spimemio_cfgreg_sel ? mem_wstrb : 4'b 0000),
		.cfgreg_di(mem_wdata),
		.cfgreg_do(spimemio_cfgreg_do)
	);

	simpleuart simpleuart (
		.clk         (clk),
		.resetn      (resetn),

		.ser_tx      (ser_tx),
		.ser_rx      (ser_rx),

		.reg_div_we  (simpleuart_reg_div_sel ? mem_wstrb : 4'b 0000),
		.reg_div_di  (mem_wdata),
		.reg_div_do  (simpleuart_reg_div_do),

		.reg_dat_we  (simpleuart_reg_dat_sel ? mem_wstrb[0] : 1'b 0),
		.reg_dat_re  (simpleuart_reg_dat_sel && !mem_wstrb),
		.reg_dat_di  (mem_wdata),
		.reg_dat_do  (simpleuart_reg_dat_do),
		.reg_dat_wait(simpleuart_reg_dat_wait)
	);


	//Data processor instantiation.

	data_proc dataproc (
		.clk(clk),
		.rstn(resetn),
		.sensor_clk(clk), 			//Using the same clock as proc (or) soc for the producer too, initially.
		
        .pixel_in(pixel),
        .valid_in(valid),

        .pixel_out(pixel_out),
        .ready_out(ready),
        .valid_out(valid_out),
        
		//Instantiations based on the variables defined by the CPU.
        .addr_in(mem_addr[4:0]),			//CPU sends a 32 bit addr, but we only need the offset i.e. 5 LSBs to determine mode_reg & kernel_reg.
        .wr_data_in(mem_wdata),				
        .write_en(proc_sel & |mem_wstrb),	//Write action only if CPU is pointing at any 0x03.. address or the Write Strobe signal is high.
        .rd_data_out(proc_do)				//Connects proc output to the READ MUX.
	);


	//----------------------------------------------------------------

	always @(posedge clk)
		ram_ready <= mem_valid && !mem_ready && mem_addr < 4*MEM_WORDS;

	soc_mem #(
		.WORDS(MEM_WORDS)
	) memory (
		.clk(clk),
		.wen((mem_valid && !mem_ready && mem_addr < 4*MEM_WORDS) ? mem_wstrb : 4'b0),
		.addr(mem_addr[23:2]),
		.wdata(mem_wdata),
		.rdata(ram_rdata)
	);
endmodule

module soc_mem #(
	parameter integer WORDS = 256
) (
	input clk,
	input [3:0] wen,
	input [21:0] addr,
	input [31:0] wdata,
	output reg [31:0] rdata
);
	reg [31:0] mem [0:WORDS-1];

	always @(posedge clk) begin
		rdata <= mem[addr];
		if (wen[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
		if (wen[1]) mem[addr][15: 8] <= wdata[15: 8];
		if (wen[2]) mem[addr][23:16] <= wdata[23:16];
		if (wen[3]) mem[addr][31:24] <= wdata[31:24];
	end
endmodule

