.section .text
.globl _start

# Foreground code polls the button; timer interrupts move the LEDs.
_start:
    addi sp, x0, 256         # Top of the 256-byte data RAM.
    lui  s0, 0x10000         # GPIO base.
    lui  s2, 0x30000         # Timer base.
    addi s3, x0, 1           # LED pattern.
    addi s4, x0, 0           # Direction: 0 = left, 1 = right.
    li   s5, TIMER_TICKS     # Timer period.
    addi s6, x0, 0           # Previous button state.
    addi t4, x0, 32          # Left edge pattern.
    addi t5, x0, 1           # Right edge pattern.
    addi a0, x0, 0           # Foreground heartbeat.
    addi a1, x0, 0           # Interrupt counter.

    sw   s3, 0(s0)           # Show the initial LED.

    addi t0, x0, 128         # mie.MTIE = 1.
    csrw mie, t0
    addi t0, x0, 8           # mstatus.MIE = 1.
    csrs mstatus, t0

    sw   s5, 0(s2)           # Start the first timer period.

main_loop:
    lw   t0, 4(s0)           # Read the synchronized button.
    beq  t0, s6, no_press
    addi s6, t0, 0
    beq  t0, x0, no_press
    xori s4, s4, 1           # Toggle direction on a press edge.

no_press:
    addi a0, a0, 1           # Foreground work continues between interrupts.
    jal  x0, main_loop

.org 0x80

timer_handler:
    addi sp, sp, -16         # Save foreground temporary registers.
    sw   t0, 0(sp)
    sw   t1, 4(sp)
    sw   t2, 8(sp)

    beq  s4, x0, move_left

move_right:
    beq  s3, t5, wrap_right
    srli s3, s3, 1
    jal  x0, update_led

wrap_right:
    addi s3, x0, 32
    jal  x0, update_led

move_left:
    beq  s3, t4, wrap_left
    slli s3, s3, 1
    jal  x0, update_led

wrap_left:
    addi s3, x0, 1

update_led:
    sw   s3, 0(s0)           # Update LEDs inside the interrupt handler.
    sw   s5, 0(s2)           # Start the next timer period.
    addi a1, a1, 1           # Count serviced interrupts.

    lw   t0, 0(sp)           # Restore foreground state.
    lw   t1, 4(sp)
    lw   t2, 8(sp)
    addi sp, sp, 16
    mret
