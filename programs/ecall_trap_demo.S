.section .text
.globl _start

_start:
    addi a0, x0, 1          # Set the initial program value.
    ecall                   # Enter the trap handler.
    addi a0, x0, 7          # Continue here after MRET.

done:
    jal  x0, done           # Hold the final result.

.org 0x80

trap_handler:
    addi a0, x0, 42         # Mark that the handler executed.

    csrr t0, mepc           # Read the trapped instruction address.
    addi t0, t0, 4          # Skip the ECALL instruction.
    csrw mepc, t0           # Store the return address.
    mret                    # Return to the main program.

    addi a0, x0, 99         # Wrong path: MRET must flush this.

trap_fail:
    jal  x0, trap_fail
