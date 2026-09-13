<div align="center">

# RV32I Pipelined Core

### 5-Stage RISC-V RV32I Processor in SystemVerilog

A synthesizable 32-bit RISC-V processor implementing a classic  
**IF → ID → EX → MEM → WB** pipeline.

![SystemVerilog](https://img.shields.io/badge/SystemVerilog-RTL-blue)
![RISC-V](https://img.shields.io/badge/RISC--V-RV32I-darkgreen)
![Pipeline](https://img.shields.io/badge/Pipeline-5--Stage-orange)
![FPGA](https://img.shields.io/badge/FPGA-Tang%20Nano%209K-purple)

</div>

---

## Overview

An educational 5-stage **RV32I processor core**, written from scratch in
SystemVerilog. It is the third project in a processor-design learning path,
after a 16-bit multicycle CPU and a single-cycle RV32I core.

| Area | Current state |
| --- | --- |
| ISA | 37 supported RV32I instructions |
| Datapath | IF → ID → EX → MEM → WB |
| Data hazards | EX-stage forwarding, WB-to-ID bypass, one-cycle load-use stall |
| Control hazards | EX-stage branch / JAL / JALR redirect and flush |
| FPGA demo | Tang Nano 9K: NOP-free hazard demo verified on hardware |
| SoC | RAM, GPIO, timer, and UART TX verified on Tang Nano 9K |

---

## Architecture

```text
          IF           ID           EX           MEM          WB
          │            │            │             │            │
     ┌────▼────┐  ┌────▼────┐  ┌────▼────┐  ┌────▼────┐  ┌────▼────┐
     │   PC    │  │ Decode  │  │   ALU   │  │ Memory  │  │Writeback│
     │ Fetch   │  │Reg File │  │ Branch  │  │ Access  │  │  MUX    │
     └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘
          │            │            │             │            │
        IF/ID        ID/EX        EX/MEM         MEM/WB        │
          │            │            │             │            │
          └────────────┴────────────┴─────────────┴────────────┘
```

Pipeline registers carry both datapath values and the control signals
belonging to each instruction.

Instruction and data memories are kept outside the processor core,
allowing a cleaner interface for future SoC and memory-system integration.

---

## Pipeline Stages

| Stage | Main Operations                                             |
| ----- | ----------------------------------------------------------- |
| IF    | PC update, instruction fetch, PC + 4                        |
| ID    | Instruction decode, register read, immediate generation     |
| EX    | ALU operation, operand selection, branch/jump decision      |
| MEM   | Load/store memory access                                    |
| WB    | ALU / memory / PC+4 result selection and register writeback |

Pipeline registers:

* `IF/ID`
* `ID/EX`
* `EX/MEM`
* `MEM/WB`

---

## Supported RV32I Instructions

| Group | Instructions |
| --- | --- |
| Register arithmetic | `ADD SUB AND OR XOR SLL SRL SRA SLT SLTU` |
| Immediate arithmetic | `ADDI ANDI ORI XORI SLLI SRLI SRAI SLTI SLTIU` |
| Loads | `LB LBU LH LHU LW` |
| Stores | `SB SH SW` |
| Branches | `BEQ BNE BLT BGE BLTU BGEU` |
| Control / upper immediate | `LUI AUIPC JAL JALR` |

---

## Repository Structure

```text
rtl/                 CPU, pipeline registers, memories and SoC peripherals
programs/            RISC-V assembly sources (all demos)
tb/                  Small self-checking SystemVerilog tests
fpga/tangnano9k/      Board top and pin constraints only
scripts/             Binary-to-HEX converter and UART monitor
build/               Generated files only; ignored by Git
  programs/          ELF, BIN and the selected program.hex image
  sim/               Compiled simulations
  waves/             VCD waveforms
  logs/              Test output and errors
  fpga/              Synthesis/P&R JSON and the .fs bitstream
Makefile             All build, test and programming commands
README.md            Architecture and usage
```


---

## Verification

The processor is verified using self-checking SystemVerilog testbenches.

| Scope | Coverage |
| --- | --- |
| ISA behavior | Arithmetic, logic, loads/stores, branches, JAL/JALR, LUI/AUIPC |
| Memory | Byte, halfword, and word accesses |
| Pipeline | Stage flow and EX→WB execution |
| Hazards | RAW forwarding, WB-to-ID bypass, load-use stall, and control-flow flush |
| Control flow | Taken branches, JAL, JALR, and not-taken branch sequencing |
| Regression | 34 directed testbenches; latest result 34/34 PASS |

Pipeline timing and stage alignment were also inspected using GTKWave.

The repository is used from **native Linux**. From the repository root:

```bash
make lint
make test
```

`make test` runs the self-checking regression and writes concise results to
the terminal. Detailed simulator output is kept in `build/logs/`; generated
waveforms go in `build/waves/`. Linting uses **Verilator** and simulation uses
**Icarus Verilog**.

---

## FPGA Implementation

Target board:

**Sipeed Tang Nano 9K — Gowin GW1NR-9**

### Current SoC checkpoint

The FPGA top instantiates `rv32i_pipelined_soc`, keeping the CPU core
separate from its memory map. RAM and peripherals share one data port; the
address decoder selects the target and a read-data multiplexer returns the
selected value to the core.

| Address | Device | Current behavior |
| --- | --- | --- |
| `0x0000_0000`–`0x0000_00FF` | Data RAM | Load and store |
| `0x1000_0000` | GPIO output | Store updates `gpio_out[31:0]` |
| `0x1000_0004` | GPIO input | Bit 0 is the active-high user-button state |
| `0x2000_0000` | UART TX data | Store sends the low byte |
| `0x2000_0004` | UART status | `1` while a transmission is in progress |
| `0x3000_0000` | Timer load | Store starts the down-counter |
| `0x3000_0004` | Timer status | `1` while the timer is busy |

On Tang Nano 9K, `gpio_out[5:0]` drives the active-low onboard LEDs. The
`gpio_demo.S` demonstration writes `21` (`0b010101`). `soc_integration_demo.S`
adds a timer-driven LED chaser, user-button direction changes, and UART
messages (`SOC READY`, then `L`/`R` on direction changes).

FPGA flow:

```text
RISC-V Assembly
      ↓
GNU RISC-V Toolchain
      ↓
ELF → BIN → HEX
      ↓
Yosys Synthesis
      ↓
nextpnr Place & Route
      ↓
Gowin Bitstream
```

Current integrated SoC (native Linux, 13 September 2026):

| Metric | Result |
| --- | ---: |
| Target clock | 27 MHz |
| Post-route maximum frequency | 42.02 MHz — PASS |
| LUT4 / DFF / BSRAM | 3351 / 802 / 2 |
| Board validation | UART, LEDs, direction change and reset confirmed |

Historical baseline `v0.1` result:

| Metric            |             Result |
| ----------------- | -----------------: |
| Maximum Frequency |      **65.71 MHz** |
| LUT4              | 2097 / 8640 (~24%) |
| DFF               |  739 / 6480 (~11%) |
| BSRAM             |       2 / 26 (~7%) |

Hazard-handled checkpoint result:

| Metric | Result |
| --- | ---: |
| Target clock | 27 MHz |
| Post-route maximum frequency | **50.14 MHz** |
| Hardware demonstration | PASS |

### NOP-free hazard demo

[`hazard_demo.S`](programs/hazard_demo.S) is a compact end-to-end program
used for both simulation and FPGA validation. It exercises a store/load pair,
load-use dependency, forwarding through a loop, a taken branch, `JAL`, and
`JALR` return, without inserting software NOPs.

Expected final state:

| Signal / state | Expected value |
| --- | ---: |
| `RAM[0]` | 5 |
| `t2` | 6 |
| `t3` | 0 |
| `a0` | 19 |

The earlier core-only board top displayed `a0 = 19` on the LEDs. The current
SoC top displays GPIO instead; `make test-hazard_demo` checks this program
in simulation.

## Quick Start

Run from the repository root on native Linux:

```bash
make help
make test
make flash-integration
make uart-monitor
```

After opening the monitor, press the design reset button for `SOC READY`.
The user button reverses the LED chaser and emits `L` or `R`.
`make flash` alone selects the GPIO demo.

See [USAGE.md](USAGE.md) for software builds, focused tests, waveforms,
adding testbenches, tool configuration and cleanup.

---

## Current Limitations

Not yet implemented:

* CSR instructions
* Exceptions and traps
* Interrupts
* Cache hierarchy
* UART RX

The GPIO user-button input still needs synchronization/debounce. Directed
tests do not establish exhaustive ISA coverage or metastability safety.

---

## Roadmap

* [x] IF stage
* [x] ID stage
* [x] EX stage
* [x] MEM stage
* [x] WB stage
* [x] 37-instruction RV32I baseline
* [x] FPGA synthesis and timing
* [x] Pipeline flow verification
* [x] EX-stage RAW forwarding, including EX/MEM and MEM/WB priority
* [x] Load-use stall and bubble insertion
* [x] Branch / jump pipeline flush
* [x] NOP-free program execution in simulation and on Tang Nano 9K
* [x] Hazard-handled FPGA synthesis, place-and-route, and timing check
* [x] GPIO, UART TX and timer SoC integration
* [x] Native Linux build, regression and integrated FPGA demo

---

## Tools

* SystemVerilog
* Icarus Verilog
* Verilator
* GTKWave
* Yosys
* nextpnr
* Gowin toolchain
* GNU RISC-V toolchain

---

## License

This project is licensed under the MIT License.
