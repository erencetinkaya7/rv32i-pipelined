.section .text
.globl _start

_start:
    addi t0, x0, 128        # Enable machine timer interrupts in mie.
    csrw mie, t0
    addi t0, x0, 8          # Enable machine interrupts globally.
    csrs mstatus, t0

    addi a0, x0, 1          # Must complete before the interrupt.
    addi a0, a0, 2          # Must restart from mepc after MRET.
    addi a0, a0, 4

done:
    jal  x0, done

.org 0x80

trap_handler:
    addi a1, x0, 42         # Mark handler execution.
    mret

    addi a0, x0, 99         # Wrong path: MRET must flush this.
