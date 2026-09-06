


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

This project implements a 5-stage pipelined **RV32I processor core** from scratch in SystemVerilog.

It is the third processor project in my computer architecture learning path:

1. Custom 16-bit multicycle CPU
2. Single-cycle RV32I processor + minimal SoC
3. **5-stage pipelined RV32I processor — current project**

The current `v0.1` baseline implements the complete datapath and supports
37 RV32I instructions.

EX-stage forwarding handles RAW dependencies for ALU operands, store data,
branch comparisons, and JALR targets. Load-use stalls and control-flow flushes
are not implemented yet; programs using those cases still require NOP padding.

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
````

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

### Arithmetic / Logic

`ADD` `SUB` `AND` `OR` `XOR`
`SLL` `SRL` `SRA` `SLT` `SLTU`

`ADDI` `ANDI` `ORI` `XORI`
`SLLI` `SRLI` `SRAI` `SLTI` `SLTIU`

### Loads

`LB` `LBU` `LH` `LHU` `LW`

### Stores

`SB` `SH` `SW`

### Branches

`BEQ` `BNE` `BLT` `BGE` `BLTU` `BGEU`

### Control / Upper Immediate

`LUI` `AUIPC` `JAL` `JALR`

---

## RTL Structure

```text
rtl/
├── core/
│   ├── alu.sv
│   ├── alu_decoder.sv
│   ├── branch_unit.sv
│   ├── control_unit.sv
│   ├── forwarding_unit.sv
│   ├── immediate_generator.sv
│   ├── instruction_fields.sv
│   ├── register_file.sv
│   └── rv32i_pipelined_core.sv
│
├── pipeline/
│   ├── if_id_reg.sv
│   ├── id_ex_reg.sv
│   ├── ex_mem_reg.sv
│   └── mem_wb_reg.sv
│
└── memory/
    ├── instruction_memory.sv
    └── data_memory.sv
```

---

## Verification

The processor is verified using self-checking SystemVerilog testbenches.

Current tests cover:

* IF and ID stage behavior
* EX → WB end-to-end execution
* Arithmetic and logical instructions
* Load/store operations
* Byte and halfword memory accesses
* Branches
* JAL / JALR
* LUI / AUIPC
* Pipeline stage flow
* EX-stage RAW forwarding, including store data, branch operands, JALR targets,
  JAL link values, and x0 protection
* Full supported-instruction regression

Pipeline timing and stage alignment were also inspected using GTKWave.

Run:

```bash
make lint
make test
```

Linting is performed with **Verilator** and simulation with **Icarus Verilog**.

---

## FPGA Implementation

Target board:

**Sipeed Tang Nano 9K — Gowin GW1NR-9**

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

Baseline `v0.1` result:

| Metric            |             Result |
| ----------------- | -----------------: |
| Maximum Frequency |      **65.71 MHz** |
| LUT4              | 2097 / 8640 (~24%) |
| DFF               |  739 / 6480 (~11%) |
| BSRAM             |       2 / 26 (~7%) |

Build:

```bash
cd fpga/rv32i
make
```

Flash:

```bash
make flash
```

---

## Current Limitations

The `v0.1` processor is a functional **hazard-free baseline**.

Not yet implemented:

* Load-use stall
* Pipeline bubbles
* Branch / jump flush
* CSR instructions
* Exceptions and traps
* Interrupts
* Cache hierarchy

Dependent instructions currently require NOP spacing.

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
* [x] EX-stage RAW forwarding
* [x] EX/MEM forwarding
* [x] MEM/WB forwarding
* [ ] Load-use stall and bubble insertion
* [ ] Branch / jump pipeline flush
* [ ] NOP-free program execution
* [ ] Final FPGA timing comparison

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
