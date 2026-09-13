# Using the project

Run every command from the **repository root** (the directory containing this
README and the Makefile). On the current machine:

```bash
cd /home/raze/fpga/rv32i-pipelined
make help
```

Required tools: GNU Make, Icarus Verilog, Verilator, Yosys,
nextpnr-himbaechel, gowin_pack, openFPGALoader and GNU RISC-V bare-metal GCC.
GTKWave is used for waveform inspection. The Makefile adds
`~/oss-cad-suite/bin` to PATH; override `OSS_CAD_DIR=/path/to/oss-cad-suite`
if needed. Helpers use `/usr/bin/python3` (`PYTHON` can override it); UART
monitoring requires the system `python3-serial` package.

**Run the existing board demo:**

```bash
make flash-integration
make uart-monitor
```

**Write your own software:** create `programs/my_program.S` with a `.text`
section and `_start` entry point. Existing files in `programs/` are working
assembly examples. Replace `my_program.S` below with your actual filename.

```bash
make program PROGRAM=programs/my_program.S # Assembly -> ELF/BIN/HEX only
make fpga PROGRAM=programs/my_program.S    # Also build the FPGA bitstream
make flash PROGRAM=programs/my_program.S   # Also load the board SRAM
```

These are progressively larger operations, not three mandatory commands:
`make flash PROGRAM=...` performs all necessary build steps itself.
`make` alone only compiles the core; it neither runs tests nor programs the board.
`make flash` without `PROGRAM` selects the GPIO demo. Selection is per command:
a previous `make program PROGRAM=...` does not change the next command's default.

Tests select their own assembly examples. `PROGRAM=...` does not make the
existing testbenches verify an arbitrary new program; new behavior needs an
appropriate testbench or explicit observable board result.

Instruction memory is embedded in the bitstream, with a 1024-byte capacity.
Changing the assembly changes the instruction image and triggers synthesis
and place/route. Identical image content skips those expensive steps if RTL
and board constraints are also unchanged. Oversized programs are rejected.

**Change hardware:** edit `rtl/`, run a focused test, then lint and regression:

```bash
make test-load_use_stall # Example: choose the test relevant to your change
make lint
make test
make flash-integration  # When validating the change on the board
```

Close the UART monitor before flashing. On native Linux the normal flow does
not require unloading/reloading `ftdi_sio`. After opening the monitor, press
the **design reset button** to see `SOC READY`. The user button reverses the
LED chaser and emits `L` or `R`. This reset restarts the CPU/peripherals; it
does not erase the FPGA configuration. SRAM programming is lost on power-off
or FPGA reconfiguration.

To inspect ports or choose a different one:

```bash
make uart-ports
make uart-monitor UART_PORT=/dev/ttyUSB1
```

`UART_PORT` also accepts a stable `/dev/serial/by-id/...` path. If access is
denied, check Linux USB udev permissions for openFPGALoader and membership in
`dialout` for the UART port. Do not run the whole build as root.

To remove generated files:

```bash
make clean
```

This removes only `build/`; sources remain. The next build recreates the required
subdirectories. All ELF/BIN/HEX, simulation executables, VCD, log, synthesis JSON
and bitstream files now live under `build/`, so `.gitignore` needs only `/build/`
for those outputs. Python caches and editor temporary files have separate rules.

The Makefile is a list of command recipes: `target: prerequisites` followed by
commands. Its sections are tool/path settings, test lists, simulation, software
build, FPGA build, and shortcuts. For example, `flash: fpga` means the FPGA
image is prepared before openFPGALoader runs. `$@` means the current output
filename and `$<` means its first prerequisite. Detailed Make syntax is optional
for daily work; `make help` lists the commands you use.


`programs/nested_func.S` is an earlier core-only program retained
as a second hardware example. It uses stack RAM and nested `JAL`/`JALR` calls,
then leaves `a0 = 11`.


## Focused tests and waveforms

`make wave` originally selected RAW hazard for convenience. It is not a special
class of test. Select any test that writes `build/waves/<name>.vcd`:

```bash
make wave TEST=load_use_stall
make wave TEST=branch_forwarding
```

The command first runs the test, checks that its VCD exists, then opens GTKWave.
Without TEST it defaults to `raw_hazard`. Tests without waveform dumping still
run with `make test-<name>`, but cannot be opened with `make wave` until a dump
is added. To open an existing waveform without rerunning its test:

```bash
gtkwave build/waves/load_use_stall.vcd
```

## Adding a testbench

1. Create `tb/example_tb.sv` with a top module named `example_tb`.
2. Use `$fatal(1, ...)` on a failed check and print PASS after successful checks.
   Bound waits with a timeout and release reset away from the rising clock edge.
3. Run `make test-example`. The generic rule finds the file automatically;
   no Makefile edit is needed for this single-test command.
4. To include it in `make test`, add `example` to the appropriate STAGE_TESTS,
   ISA_TESTS, HAZARD_TESTS or SOC_TESTS list in the Makefile.
5. If it needs assembled software, add a line like
   `test-example: TEST_PROGRAM = programs/example.S`, following existing entries.
   Assembly tests read `build/programs/program.hex` and run sequentially.

For waveform output, add these calls to an initial block:

```systemverilog
$dumpfile("build/waves/example.vcd");
$dumpvars(0, example_tb);
```

## Verification record and limits

The current design passed 34/34 directed tests and a 27 MHz FPGA timing target
(42.02 MHz final post-route estimate). UART boot output was captured; LED motion,
direction change and design reset were confirmed on hardware. Six unused-field
or signal lint warnings remain visible.

Tests cover ISA examples, forwarding priority/WB-to-ID bypass, load-use hazards,
branch conditions, timer boundaries and wrong-path MMIO stores. They are not an
exhaustive ISA compliance or coverage result. In a temporary RTL copy, removing
the EX redirect bubble caused the MMIO test to reject the forbidden store.

## Clean versus clearing the board

`make clean` deletes all generated files in `build/`, including compiled
software and FPGA images, so the next build starts from scratch. It does not
change the running FPGA or delete source files. The previous single-cycle
project's `clean` target did the same job for its ELF/BIN/HEX/JSON/FS files.
No `clear` target was found in the inspected Makefile history.

```bash
make clean
make flash-integration
```

This rebuilds and reloads the demo. Ordinary edits do not require cleaning first.
SRAM configuration is lost on power-off; the design reset button restarts the
CPU/peripherals while keeping the FPGA configuration.
