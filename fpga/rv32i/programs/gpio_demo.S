.section .text
.globl _start

# Write 21 (binary 010101) to the GPIO output register, then stop.
_start:
    lui  t0, 0x10000        # t0 = GPIO_OUT_ADDR = 0x1000_0000
    addi t1, x0, 21
    sw   t1, 0(t0)

done:
    jal  x0, done
