.section .text
.globl _start

_start:
    lui  s0, 0x20000        # UART base: 0x2000_0000
    lui  s1, 0x10000        # GPIO base: 0x1000_0000

wait_rx:
    lw   t0, 12(s0)         # UART_RX_STATUS
    andi t0, t0, 1          # Keep data_valid only.
    beq  t0, x0, wait_rx

    lw   t1, 8(s0)          # UART_RX_DATA
    sw   t1, 0(s1)          # Show received byte on GPIO.
    sw   x0, 16(s0)         # UART_RX_CLEAR

halt:
    jal  x0, halt
