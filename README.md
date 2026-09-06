


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
| Data hazards | EX-stage forwarding and one-cycle load-use stall |
| Control hazards | Branch / JAL / JALR flush pending |
| FPGA baseline | Tang Nano 9K, 65.71 MHz |

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

## RTL Structure

```text
rtl/
├── core/
│   ├── alu.sv
│   ├── alu_decoder.sv
│   ├── branch_unit.sv
│   ├── control_unit.sv
│   ├── forwarding_unit.sv
│   ├── hazard_unit.sv
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

| Scope | Coverage |
| --- | --- |
| ISA behavior | Arithmetic, logic, loads/stores, branches, JAL/JALR, LUI/AUIPC |
| Memory | Byte, halfword, and word accesses |
| Pipeline | Stage flow and EX→WB execution |
| Hazards | EX-stage RAW forwarding; load-use detection, stall, and bubble |
| Regression | Full supported-instruction suite |

Pipeline timing and stage alignment were also inspected using GTKWave.

On Linux:

```bash
make lint
make test
```

On Windows, first load the locally installed OSS CAD Suite environment, then
compile and run the desired testbench with Icarus Verilog. The project keeps
the generated simulator files under `build/`.

Linting uses **Verilator**; simulation uses **Icarus Verilog**.

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

Not yet implemented:

* Branch / jump flush
* CSR instructions
* Exceptions and traps
* Interrupts
* Cache hierarchy

Control-flow instructions currently need NOP padding until the flush checkpoint
is complete.

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
