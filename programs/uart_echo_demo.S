.section .text
.globl _start

_start:
    lui  s0, 0x20000        # UART base: 0x2000_0000

wait_rx:
    lw   t0, 12(s0)         # UART_RX_STATUS
    andi t0, t0, 1          # Keep data_valid only.
    beq  t0, x0, wait_rx

    lw   a0, 8(s0)          # UART_RX_DATA
    sw   x0, 16(s0)         # UART_RX_CLEAR

wait_tx:
    lw   t0, 4(s0)          # UART_TX_STATUS: busy = 1
    bne  t0, x0, wait_tx

    sw   a0, 0(s0)          # UART_TX_DATA
    jal  x0, wait_rx
