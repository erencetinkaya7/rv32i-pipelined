param(
    [ValidateSet("Test", "Lint", "Build", "Flash")]
    [string]$Action = "Test",

    # Assembly source under fpga/rv32i. Used only by the Build action.
    [ValidatePattern("^(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.S$")]
    [string]$Program = "hazard_demo.S"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$fpgaDir = Join-Path $repoRoot "fpga\rv32i"
$toolRoot = Join-Path $repoRoot "build\tools\oss-cad-suite"
$bitstream = Join-Path $fpgaDir "rv32i.fs"

if (-not (Test-Path $toolRoot)) {
    throw "OSS CAD Suite was not found at $toolRoot"
}

# Icarus needs this directory explicitly on this Windows installation.
function Enable-OssCadSuite {
    Remove-Item Env:YOSYSHQ_ROOT -ErrorAction SilentlyContinue
    . (Join-Path $toolRoot "environment.ps1")
}

function Get-RtlFiles {
    Get-ChildItem (Join-Path $repoRoot "rtl\core\*.sv"),
                  (Join-Path $repoRoot "rtl\pipeline\*.sv"),
                  (Join-Path $repoRoot "rtl\memory\*.sv") |
        ForEach-Object FullName
}

function Convert-ToWslPath([string]$windowsPath) {
    $fullPath = (Resolve-Path $windowsPath).Path
    $drive = $fullPath.Substring(0, 1).ToLower()
    $rest = $fullPath.Substring(2).Replace("\", "/")
    return "/mnt/$drive$rest"
}

switch ($Action) {
    "Test" {
        # WSL owns simulation as well as the GNU RISC-V compiler. This avoids
        # the Windows Icarus launcher issue while keeping the test command short.
        $wslRepoRoot = Convert-ToWslPath $repoRoot
        wsl.exe bash -lc "cd '$wslRepoRoot' && make -C fpga/rv32i PROGRAM=hazard_demo.S program.hex && iverilog -g2012 -s hazard_demo_tb -o build/hazard_demo_tb_sim rtl/core/*.sv rtl/pipeline/*.sv rtl/memory/*.sv tb/hazard_demo_tb.sv && vvp build/hazard_demo_tb_sim"
        exit $LASTEXITCODE
    }

    "Lint" {
        Enable-OssCadSuite
        $env:VERILATOR_ROOT = Join-Path $toolRoot "share\verilator"
        & (Join-Path $toolRoot "bin\verilator_bin.exe") --lint-only -Wall -Wno-fatal `
            --top-module rv32i_pipelined_core (Get-RtlFiles)
        exit $LASTEXITCODE
    }

    "Build" {
        $source = Join-Path $fpgaDir $Program
        if (-not (Test-Path $source)) {
            throw "Assembly source was not found: $source"
        }

        # WSL owns the GNU RISC-V compiler: .S -> ELF -> BIN -> program.hex.
        $wslFpgaDir = Convert-ToWslPath $fpgaDir
        wsl.exe bash -lc "cd '$wslFpgaDir' && make PROGRAM='$Program' program.hex"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        # Windows OSS CAD Suite turns the RTL plus program.hex into an FPGA bitstream.
        Enable-OssCadSuite
        $rtl = Get-RtlFiles
        Push-Location $fpgaDir
        try {
            yosys -p "read_verilog -sv $rtl top.sv; synth_gowin -top top -json rv32i.json"
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

            nextpnr-himbaechel --json rv32i.json --write rv32i_pnr.json `
                --device GW1NR-LV9QN88PC6/I5 --freq 27 --seed 30 `
                --vopt family=GW1N-9C --vopt cst=tangnano9k.cst
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

            gowin_pack -d GW1N-9C -o rv32i.fs rv32i_pnr.json
            exit $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
    }

    "Flash" {
        if (-not (Test-Path $bitstream)) {
            throw "Bitstream was not found. Run: .\\scripts\\windows.ps1 -Action Build -Program $Program"
        }

        Enable-OssCadSuite
        openFPGALoader -b tangnano9k $bitstream
        exit $LASTEXITCODE
    }
}
