# Complete this make file such that when invoked "make all" it should run the simulation and dump the vcd file.
# Also implement "make clean" to remove the build files.
# Referred the uart_dv's Makefile to create this makefile for the processor as a peripheral.

CROSS=riscv64-unknown-elf-
CFLAGS=

all : sim

sim: dataproc_tb.vvp dataproc_firmware.hex
	vvp -N $< +firmware=dataproc_firmware.hex

dataproc_tb.vvp: dataproc_tb.v \
    rvsoc_wrapper.v \
    spimemio.v \
    simpleuart.v \
    rvsoc.v \
    picorv32.v \
    spiflash.v \
    ../../Part_B/data_prod_proc/data_proc.v \
    ../../Part_B/data_prod_proc/data_prod.v \
    ../../Part_B/data_prod_proc/async_fifo_top.v \
    ../../Part_B/data_prod_proc/fifo_memory.v \
    ../../Part_B/data_prod_proc/line_buffer.v \
    ../../Part_B/data_prod_proc/ptr_2ff_sync.v \
    ../../Part_B/data_prod_proc/read_logic.v \
    ../../Part_B/data_prod_proc/reset_2ff_sync.v \
    ../../Part_B/data_prod_proc/write_logic.v \
    ../../Part_B/data_prod_proc/fwft_wrapper.v
	iverilog -s dataproc_tb -o $@ $^

dataproc_firmware.elf: sections.ld start.s firmware.c
	$(CROSS)gcc $(CFLAGS) -mabi=ilp32 -march=rv32ic -Wl,-Bstatic,-T,sections.ld,--strip-debug -ffreestanding -nostdlib -o dataproc_firmware.elf start.s firmware.c

dataproc_firmware.hex: dataproc_firmware.elf
	$(CROSS)objcopy -O verilog dataproc_firmware.elf dataproc_firmware.hex

clean:
	rm -f dataproc_tb.vvp dataproc_tb.vcd spiflash_tb.vvp spiflash_tb.vcd
	rm -f dataproc_firmware.elf dataproc_firmware.hex dataproc_firmware.bin
