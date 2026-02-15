#include <stdint.h>
#include <stdbool.h>

#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)

/*---------Define your data processing registers addresses here -----------------*/
#define reg_dataproc_config  (*(volatile uint32_t*)0x04000000) //
#define reg_dataproc_status (*(volatile uint32_t*)0x04000010)  //Status(Bit 0 = Valid)
#define reg_dataproc_result (*(volatile uint32_t*)0x04000014)  //Result (Pixel Value)
/*---------------------------------------------------------------------------------*/

void putchar(char c);
void print(const char *p);

void process_and_print(int count) {
    for (int i = 0; i < count; i++) {
        //Poll i.e. wait until processor gives "valid".
        while ((reg_dataproc_status & 1) == 0);

        //Read i.e. get the processed pixel from 0x14
        uint32_t pixel = reg_dataproc_result;

        //Print i.e. write to UART
        reg_uart_data = pixel; 
    }
}

void main()
{
    reg_uart_clkdiv = 104;

    /*Write the code to read & write to your data proc module
     * and print the output pixels using print() function*/

    print("\n");
    print("----------------------------------\n");
    print("STARTING HARDWARE TEST\n");
    print("----------------------------------\n");

    //Mode 0 : Bypass
    print("Setting Mode: BYPASS (0)...\n");
    reg_dataproc_config = 0;                                        //Write 0 to 0x04000000
    
    //Assume 16 pixels are coming through.
    process_and_print(16);                                          // Process and print results
    
    print("Done.\n\n");

    //Mode 1 : Invert
    print("Setting Mode: INVERT (1)...\n");
    reg_dataproc_config = 1;                                        // Write 1 to 0x04000000
    process_and_print(16);                                          // Process and print results
    print("Done.\n\n");

    //Mode 2 : Convolution
    print("Setting Mode: CONVOLUTION (2)...\n");
    reg_dataproc_config = 2;                                        // Write 2 to 0x04000000
    process_and_print(16);                                          // Process and print results
    print("Done.\n\n");

    print("ALL TESTS COMPLETE.\n");

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

