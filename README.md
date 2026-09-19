<div align="center">

# RV32I Pipelined SoC

A synthesizable five-stage RISC-V processor and minimal SoC written in SystemVerilog.

![SystemVerilog](https://img.shields.io/badge/SystemVerilog-RTL-2C4F7C)
![RISC-V](https://img.shields.io/badge/RISC--V-RV32I-283272)
![Pipeline](https://img.shields.io/badge/Pipeline-5%20stage-CB4B16)
![FPGA](https://img.shields.io/badge/FPGA-Tang%20Nano%209K-6F42C1)
![Tests](https://img.shields.io/badge/regression-40%2F40%20pass-22863A)

</div>

## Overview

This project implements a 32-bit RISC-V processor with a classic
**IF -> ID -> EX -> MEM -> WB** pipeline. It started as a core-only design and
now runs as a small SoC with RAM, GPIO, UART TX/RX, a timer, machine-mode traps,
and precise timer interrupts.

The project is built as a learning platform: each architectural feature is
connected from assembly and ISA behavior through the datapath, RTL, simulation,
waveforms, synthesis, and physical FPGA behavior.

| Area | Current implementation |
| --- | --- |
| Base ISA | 37 RV32I instructions |
| Pipeline | Five stages with four pipeline registers |
| Data hazards | EX/MEM and MEM/WB forwarding, WB-to-ID bypass, load-use stall |
| Control hazards | EX-stage redirect and flush for branches, JAL, JALR, traps, and MRET |
| Machine system subset | ECALL, MRET, CSRRW, CSRRS |
| Interrupts | Precise machine timer interrupt with pending and enable state |
| SoC | 256-byte data RAM, GPIO, timer, UART TX/RX |
| FPGA | Tang Nano 9K, 27 MHz board clock |
| Verification | 40/40 directed self-checking tests |

## Architecture

```text
                         +------------------------------+
                         |        Machine CSRs          |
                         | mstatus mie mip mtvec         |
                         | mepc mcause                   |
                         +---------------+--------------+
                                         |
                                         v
+---------+    +---------+    +---------+    +---------+    +---------+
|   IF    | -> |   ID    | -> |   EX    | -> |   MEM   | -> |   WB    |
| PC/IMEM |    | Decode  |    | ALU     |    | RAM/MMIO|    | Regfile |
+----+----+    +----+----+    +----+----+    +----+----+    +----+----+
     |              |              |              |              |
     +---- IF/ID ---+--- ID/EX ----+--- EX/MEM ---+--- MEM/WB ---+
                                   |
                      branch / jump / trap redirect
```

The processor exposes separate instruction and data interfaces. The SoC owns
instruction memory, data RAM, address decoding, and peripherals.

### Pipeline control

- ALU operands can be forwarded from EX/MEM or MEM/WB.
- A load-use dependency freezes PC and IF/ID for one cycle and inserts a bubble
  into ID/EX.
- Taken branches and jumps are resolved in EX and flush younger instructions.
- Redirects have priority over a simultaneous load-use stall.
- IF/ID carries a valid bit so an interrupt never saves the PC of a reset or
  flush bubble.

### Precise interrupt boundary

A timer interrupt is accepted between the EX and ID instructions:

```text
Older MEM/WB work     -> completes
Current EX instruction -> completes
Current ID instruction -> saved in mepc and flushed
Younger IF instruction -> flushed
```

After the handler executes `MRET`, execution resumes from the saved ID
instruction. This prevents an interrupted instruction from being skipped or
executed twice.

## Supported instructions

| Group | Instructions |
| --- | --- |
| Register arithmetic | `ADD SUB AND OR XOR SLL SRL SRA SLT SLTU` |
| Immediate arithmetic | `ADDI ANDI ORI XORI SLLI SRLI SRAI SLTI SLTIU` |
| Loads | `LB LBU LH LHU LW` |
| Stores | `SB SH SW` |
| Branches | `BEQ BNE BLT BGE BLTU BGEU` |
| Control and upper immediate | `LUI AUIPC JAL JALR` |
| Machine system subset | `ECALL MRET CSRRW CSRRS` |

`CSRRW` and `CSRRS` are the implemented part of the Zicsr extension.
Assembler aliases such as `csrw`, `csrr`, and `csrs` are therefore usable.
The full Zicsr extension is not yet implemented.

## Machine-mode traps and interrupts

| CSR | Address | Implemented role |
| --- | ---: | --- |
| `mstatus` | `0x300` | Global interrupt enable and previous enable state |
| `mie` | `0x304` | Machine timer interrupt enable |
| `mtvec` | `0x305` | Direct-mode trap handler base |
| `mepc` | `0x341` | Resume PC |
| `mcause` | `0x342` | ECALL or machine timer interrupt cause |
| `mip` | `0x344` | Latched machine timer pending bit |

The timer produces a one-cycle completion pulse. `mip.MTIP` latches that pulse
until the CPU accepts it, so an interrupt is not lost while interrupts are
temporarily disabled.

A timer interrupt is accepted when:

```text
mstatus.MIE && mie.MTIE && mip.MTIP
```

Trap entry saves `mepc` and `mcause`, moves `MIE` into `MPIE`, disables
new interrupts, and redirects to `mtvec`. `MRET` restores the previous
interrupt-enable state and resumes at `mepc`.

## SoC memory map

| Address | Device | Access |
| --- | --- | --- |
| `0x0000_0000-0x0000_00FF` | Data RAM | Byte, halfword, and word loads/stores |
| `0x1000_0000` | GPIO output | Store updates `gpio_out` |
| `0x1000_0004` | GPIO input | Bit 0 reports the synchronized user button |
| `0x2000_0000` | UART TX data | Store transmits the low byte |
| `0x2000_0004` | UART TX status | Bit 0 is high while TX is busy |
| `0x2000_0008` | UART RX data | Read returns the received byte |
| `0x2000_000C` | UART RX status | Bit 0 valid, bit 1 framing error |
| `0x2000_0010` | UART RX clear | Store clears RX status |
| `0x3000_0000` | Timer load | Store starts the countdown |
| `0x3000_0004` | Timer status | Bit 0 is high while the timer is busy |

## FPGA demonstrations

### Timer-interrupt demo

```bash
make flash-interrupt
```

The foreground program polls the user button while timer interrupts move one
active LED about every half-second. Pressing the user button reverses direction.
The design reset button restarts the CPU and peripherals.

The interrupt handler:

1. Saves temporary registers on the data-RAM stack.
2. Advances or wraps the LED pattern.
3. Writes the new pattern to GPIO.
4. Reloads the one-shot timer.
5. Restores the saved registers.
6. Returns with `MRET`.

This demo passed simulation, synthesis, timing, and physical Tang Nano 9K
validation.

### Other demos

```bash
make flash-integration   # Polling LED chaser, button and UART messages
make flash-uart          # UART transmit demo
make flash-gpio          # Static GPIO pattern
```

For UART monitoring:

```bash
make uart-ports
make uart-monitor UART_PORT=/dev/ttyUSB1
```

## Build and verification

Run commands from the repository root:

```bash
make help
make lint
make test
```

Useful focused commands:

```bash
make test-ecall_trap
make test-timer_interrupt
make test-soc_timer_interrupt
make wave TEST=timer_interrupt
make wave TEST=soc_timer_interrupt
```

Generated files are kept under `build/`:

| Directory | Contents |
| --- | --- |
| `build/programs/` | ELF, BIN, and selected `program.hex` |
| `build/sim/` | Compiled simulations |
| `build/waves/` | VCD waveforms |
| `build/logs/` | Detailed test output |
| `build/fpga/` | Synthesis, place-and-route, and bitstream files |

### Current results

| Check | Result |
| --- | ---: |
| Directed regression | **40/40 PASS** |
| Verilator lint | PASS with visible unused-field warnings |
| FPGA target clock | **27.00 MHz** |
| Post-route estimate | **46.71 MHz** |
| Timer-interrupt board demo | **PASS** |
| Generated bitstream | `build/fpga/rv32i.fs` |

The directed tests cover ISA behavior, forwarding, load-use hazards, control
flushes, subword memory access, UART RX/TX, timer boundaries, ECALL/MRET, CSR
access, precise interrupt return, MMIO integration, and physical-demo behavior.
They are not a formal proof or a complete RISC-V compliance suite.

## Repository layout

```text
rtl/
  core/               Datapath, control, register file, CSR file
  pipeline/           IF/ID, ID/EX, EX/MEM, MEM/WB registers
  memory/             Instruction and data memories
  peripherals/        Timer and UART blocks
  soc/                GPIO and SoC integration
programs/              Bare-metal RISC-V assembly demos
tb/                    Self-checking SystemVerilog testbenches
fpga/tangnano9k/       Board top and pin constraints
scripts/               Binary conversion and UART monitor helpers
Makefile               Build, test, waveform, FPGA, and flash commands
USAGE.md               Detailed local workflow
```

## Toolchain

- GNU RISC-V bare-metal toolchain
- Icarus Verilog
- Verilator
- GTKWave
- Yosys
- nextpnr-himbaechel
- gowin_pack
- openFPGALoader

The default Makefile setup expects OSS CAD Suite at `~/oss-cad-suite`. Override
`OSS_CAD_DIR` if it is installed elsewhere.

## Current limits

- Only machine mode is implemented.
- CSR instructions are limited to `CSRRW` and `CSRRS`.
- `mtvec` supports direct mode only.
- Nested, external, illegal-instruction, and misalignment traps are not
  implemented.
- UART RX stores one byte and has no overrun handling.
- The user button is synchronized but not debounced.
- There are no caches or memory protection mechanisms.

## Next checkpoints

1. Review interrupt waveforms and consolidate the trap/CSR architecture.
2. Add selected exception behavior only where it improves architectural
   understanding.
3. Introduce startup code, a linker layout, stack conventions, and small C
   programs.
4. Measure critical paths and work toward higher clock targets.
5. Build a larger interrupt-driven SoC application.

See [USAGE.md](USAGE.md) for the complete command reference and daily workflow.

## License

This project is licensed under the MIT License.
