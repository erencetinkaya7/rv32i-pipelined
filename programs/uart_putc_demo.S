.section .text
.globl _start

# Send one readable UART message, then stop writing peripherals.
_start:
    lui  s0, 0x20000       # s0 = UART base = 0x2000_0000

    addi a0, x0, 'R'; jal ra, putc
    addi a0, x0, 'V'; jal ra, putc
    addi a0, x0, '3'; jal ra, putc
    addi a0, x0, '2'; jal ra, putc
    addi a0, x0, 'I'; jal ra, putc
    addi a0, x0, ' '; jal ra, putc
    addi a0, x0, 'U'; jal ra, putc
    addi a0, x0, 'A'; jal ra, putc
    addi a0, x0, 'R'; jal ra, putc
    addi a0, x0, 'T'; jal ra, putc
    addi a0, x0, ' '; jal ra, putc
    addi a0, x0, 'O'; jal ra, putc
    addi a0, x0, 'K'; jal ra, putc
    addi a0, x0, '!'; jal ra, putc
    addi a0, x0, 10;  jal ra, putc

done:
    jal  x0, done

# a0 is the character argument. Wait for idle, then write UART TX.
putc:
wait_uart:
    lw   t0, 4(s0)
    bne  t0, x0, wait_uart
    sw   a0, 0(s0)
    jalr x0, 0(ra)
