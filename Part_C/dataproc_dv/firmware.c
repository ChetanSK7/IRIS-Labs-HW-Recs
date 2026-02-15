#include <stdint.h>
#include <stdbool.h>

#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)

/*---------Define your data processing registers addresses here -----------------*/
#define reg_dataproc_config  (*(volatile uint32_t*)0x04000000)

//DMA HANDLES STATUS AND RESULT FROM NOW ON.
// #define reg_dataproc_status (*(volatile uint32_t*)0x04000010)  //Status(Bit 0 = Valid)
// #define reg_dataproc_result (*(volatile uint32_t*)0x04000014)  //Result (Pixel Value)

#define reg_dma_src      (*(volatile uint32_t*)0x05000000) // Source Address
#define reg_dma_count    (*(volatile uint32_t*)0x05000004) // Transfer Count
#define reg_dma_ctrl     (*(volatile uint32_t*)0x05000008) // Control Register
#define reg_dma_dst      (*(volatile uint32_t*)0x0500000C) // Destination Address

/*---------------------------------------------------------------------------------*/


//GLOBAL BUFFER IN RAM (PLACE WHERE DMA PUTS THE PIXELS)
volatile uint32_t pixel_buffer[16];

void putchar(char c);
void print(const char *p);

/*
void process_and_print(int count) {
    for (int i = 0; i < count; i++) {
        // 1. POLL: Wait for Accelerator to say "Valid" (Bit 0 of 0x10)
        while ((reg_dataproc_status & 1) == 0);
        // 2. READ: Get the processed pixel from 0x14
        uint32_t pixel = reg_dataproc_result;
        // 3. PRINT: Write to UART
        // This sends the raw byte. The Testbench will display it as "Serial data: [value]"
        reg_uart_data = pixel;
    }
}
*/


/*
void main()
{
    reg_uart_clkdiv = 104;
    print("\n");
    print("----------------------------------\n");
    print("STARTING HARDWARE TEST\n");
    print("----------------------------------\n");
    // TEST 1: BYPASS MODE (0)
    print("Setting Mode: BYPASS (0)...\n");
    reg_dataproc_config = 0;   // Write 0 to 0x04000000
    // CHANGE: Use the polling function instead of delay!
    // We assume 1024 pixels are coming through.
    process_and_print(16);  

    print("Done.\n\n");

    // TEST 2: INVERT MODE (1)
    print("Setting Mode: INVERT (1)...\n");
    reg_dataproc_config = 1;   // Write 1 to 0x04000000
    process_and_print(16);   // Process and print results
    print("Done.\n\n");

    // TEST 3: CONVOLUTION MODE (2)
    print("Setting Mode: CONVOLUTION (2)...\n");
    reg_dataproc_config = 2;   // Write 2 to 0x04000000
    process_and_print(16);   // Process and print results
    print("Done.\n\n");
    print("ALL TESTS COMPLETE.\n");

    // Stop here
    while(1);
}

*/
void dma_transfer(uint32_t src, uint32_t dst, uint32_t count) {
    reg_dma_src = src;
    reg_dma_dst = dst;
    reg_dma_count = count;

    //ctrl_sig_reg bits and their representations:
    //Bit 0: dma_active (1 : Start)
    //Bit 1: auto_mode (Auto-handled by hardware)
    //Bit 2: inc_src (0 : Fixed Address for Accelerator)
    //Bit 3: inc_dstn (1 : Increment Address for RAM)
    //Configuration: inc_dstn << 3 | inc_src << 2 | dma_active << 0; { Value = (1<<3) | (0<<2) | 1 = 9 }
    reg_dma_ctrl = 9;

    // When DMA is done, Bit 0 clears to 0.
    while ((reg_dma_ctrl & 1) == 1);
}



void main() {
    reg_uart_clkdiv = 100;
    print("\n==================================\n");
    print("      SOC DMA SYSTEM TEST         \n");
    print("==================================\n");

    //TEST 1: BYPASS MODE (0)
    print("\n[TEST 1] Mode: BYPASS (0)...\n");
    reg_dataproc_config = 0;                                                    //Set processor to Mode 0

    for(int i=0; i<16; i++) pixel_buffer[i] = 0xAA;                             //Fill with garbage

    //Mode 0 passes pixels through unchanged.
    dma_transfer(0x04000014, (uint32_t)pixel_buffer, 16);
    print("DMA Finished. Results:\n");

    //Print results
    for (int i = 0; i < 16; i++) {
        reg_uart_data = pixel_buffer[i];
    }


    //TEST 2: INVERT MODE (1)

    print("\n\n[TEST 2] Mode: INVERT (1)...\n");
    reg_dataproc_config = 1;                                                    //Set processor to Mode 1

    for(int i=0; i<16; i++) pixel_buffer[i] = 0xBB;                             //Fill with garbage

    //Mode 1 inverts pixels (0 -> 255, etc.)
    dma_transfer(0x04000014, (uint32_t)pixel_buffer, 16);
    print("DMA Finished. Results:\n");

    //Print results
    for (int i = 0; i < 16; i++) {
        reg_uart_data = pixel_buffer[i];
    }

    //TEST 3: CONVOLUTION MODE (2)
 
    print("\n\n[TEST 3] Mode: CONVOLUTION (2)...\n");
    reg_dataproc_config = 2;                                                    //Set processor to Mode 2

    for(int i=0; i<16; i++) pixel_buffer[i] = 0xCC;                             //Fill with garbage

    //Mode 2 applies the 3x3 Kernel
    dma_transfer(0x04000014, (uint32_t)pixel_buffer, 16);
    print("DMA Finished. Results:\n");

    //Print results
    for (int i = 0; i < 16; i++) {
        reg_uart_data = pixel_buffer[i];
    }

    print("\n\n==================================\n");
    print("      ALL TESTS COMPLETE          \n");
    print("==================================\n");

    while(1);
}


void putchar(char c)
{
    if (c == '\n')
        putchar('\r');
    reg_uart_data = c;
}


void print(const char *p)
{
    while (*p)
        putchar(*(p++));
}