.section .text
.globl _start

# Start a short timer, poll its busy bit, then report completion in a0.
_start:
    lui  t0, 0x30000       # t0 = timer base = 0x3000_0000
    addi t1, x0, 8
    sw   t1, 0(t0)         # TIMER_LOAD: begin countdown

wait_timer:
    lw   t2, 4(t0)         # TIMER_STATUS: bit 0 is busy
    bne  t2, x0, wait_timer

    addi a0, x0, 1         # Observable completion marker
done:
    jal  x0, done
