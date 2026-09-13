.section .text
.globl _start

# GPIO + button + timer + UART demonstration.
# Button: reverse chaser direction. Reset button: restart the FPGA design.

_start:
    lui  s0, 0x10000        # GPIO base
    lui  s1, 0x20000        # UART base
    lui  s2, 0x30000        # timer base
    addi s3, x0, 1          # LED pattern
    addi s4, x0, 0          # direction: 0 = left, 1 = right
    li   s5, TIMER_TICKS
    addi s6, x0, 0          # previous button state
    addi t4, x0, 32         # left edge pattern
    addi t5, x0, 1          # right edge pattern

    # "SOC READY\n"
    addi a0, x0, 'S'; jal ra, putc
    addi a0, x0, 'O'; jal ra, putc
    addi a0, x0, 'C'; jal ra, putc
    addi a0, x0, ' '; jal ra, putc
    addi a0, x0, 'R'; jal ra, putc
    addi a0, x0, 'E'; jal ra, putc
    addi a0, x0, 'A'; jal ra, putc
    addi a0, x0, 'D'; jal ra, putc
    addi a0, x0, 'Y'; jal ra, putc
    addi a0, x0, 10;  jal ra, putc

main_loop:
    sw   s3, 0(s0)          # show current LED pattern
    sw   s5, 0(s2)          # start timer

poll:
    lw   t3, 4(s0)          # GPIO input: button pressed = 1
    beq  t3, x0, save_button
    bne  s6, x0, save_button

    xori s4, s4, 1          # act only on the press edge
    addi s6, t3, 0
    beq  s4, x0, sent_left
    addi a0, x0, 'R'; jal ra, putc
    jal  x0, wait_timer

sent_left:
    addi a0, x0, 'L'; jal ra, putc
    jal  x0, wait_timer

save_button:
    addi s6, t3, 0

wait_timer:
    lw   t2, 4(s2)          # timer status: busy = 1
    bne  t2, x0, poll

    beq  s4, x0, move_left
    jal  x0, move_right

move_left:
    beq  s3, t4, wrap_left
    slli s3, s3, 1
    jal  x0, main_loop
wrap_left:
    addi s3, x0, 1
    jal  x0, main_loop

move_right:
    beq  s3, t5, wrap_right
    srli s3, s3, 1
    jal  x0, main_loop
wrap_right:
    addi s3, x0, 32
    jal  x0, main_loop

putc:
wait_uart:
    lw   t0, 4(s1)          # UART status: busy = 1
    bne  t0, x0, wait_uart
    sw   a0, 0(s1)
    jalr x0, 0(ra)
