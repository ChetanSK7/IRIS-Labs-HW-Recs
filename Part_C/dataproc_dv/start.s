.section .text                  # Place this code in the .text section, where executable code lives.
.globl _start                   # Make the '_start' symbol visible to Linker.

_start:                         # Execution begins.
    la a0, _sidata              # Source i.e. flash memory, which is slow and read-only type. (start of uninitialized data)
    la a1, _sdata               # Destination i.e. RAM, which is fast and read-write type.    (start of data)
    la a2, _edata               # Copying stops when this address is hit.                     (end of data) 

copy_data:                      # While loop that copies 4 bytes at a time from the Flash to RAM.
    bge a1, a2, zero_bss        # If current destination >= end destination, branch over to zero_bss. This prevents us from writing past an allocated memory address.   
    lw  t0, 0(a0)               # Load Word i.e. read 4 bytes from flash into the temp register t0.
    sw  t0, 0(a1)               # Store Word i.e. write those 4 bytes to RAM.
    addi a0, a0, 4              # Source/Flash pointer moves forward by 4 bytes.
    addi a1, a1, 4              # Destination/RAM pointer moves forward by 4 bytes.
    j copy_data                 # Next iteration.

zero_bss:                       # BSS: 
    la a0, _sbss                # Loads address of Start BSS i.e. start pointer at a0.
    la a1, _ebss                # Loads address of End BSS   i.e. stop pointer at a1.

clear_bss:                      # All uninitialized variables are set to 0.
    bge a0, a1, call_main       # If current address >= end address, branch over to call_main. This prevents us from writing past an allocated memory address.
    sw  zero, 0(a0)             # Store the register 'zero' (0) into RAM.
    addi a0, a0, 4              # Pointer moves forward by 4 bytes
    j clear_bss                 # Next iteration.

call_main:
    call main                   # Values copied to RAM and uninitialized variables set to zero. So now the control of the code is given to firmware.c

hang:
    j hang                      # Safety net in case main() returns i.e. infinite loop after "call_main" so that CPU falls in this trap if main() returns.        