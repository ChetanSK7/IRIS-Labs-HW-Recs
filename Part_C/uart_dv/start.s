.section .text
.globl _start

_start:
    la a0, _sidata     # source (flash)
    la a1, _sdata      # destination (RAM)
    la a2, _edata

copy_data:
    bge a1, a2, zero_bss
    lw  t0, 0(a0)
    sw  t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j copy_data

zero_bss:
    la a0, _sbss
    la a1, _ebss

clear_bss:
    bge a0, a1, call_main
    sw  zero, 0(a0)
    addi a0, a0, 4
    j clear_bss

call_main:
    call main

hang:
    j hang
