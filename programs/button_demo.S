.section .text
.globl _start

# Wait for the active-low board button, then light LED 1.
_start:
    lui  t0, 0x10000       # t0 = GPIO base = 0x1000_0000

wait_press:
    lw   t1, 4(t0)         # GPIO_IN: bit 0 is 1 while button is pressed
    beq  t1, x0, wait_press

    addi t2, x0, 1
    sw   t2, 0(t0)         # GPIO_OUT: light LED 1
done:
    jal  x0, done
