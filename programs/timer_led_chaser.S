.section .text
.globl _start

# Shift one lit LED every TIMER_TICKS clock cycles.
# Hardware default: 13,500,000 ticks = about 0.5 s at 27 MHz.
_start:
    lui  s0, 0x10000       # GPIO base  = 0x1000_0000
    lui  s1, 0x30000       # timer base = 0x3000_0000
    addi s2, x0, 1         # current LED bit pattern
    li   s3, TIMER_TICKS   # delay loaded into timer each turn

next_led:
    sw   s2, 0(s0)         # top.sv maps logical GPIO bits to active-low LEDs
    sw   s3, 0(s1)         # start countdown timer

wait_timer:
    lw   t0, 4(s1)         # read timer busy status
    bne  t0, x0, wait_timer

    slli s2, s2, 1         # move to next LED bit
    addi t1, x0, 64        # one bit beyond the six board LEDs
    bne  s2, t1, next_led

    addi s2, x0, 1         # wrap after LED 6
    jal  x0, next_led
