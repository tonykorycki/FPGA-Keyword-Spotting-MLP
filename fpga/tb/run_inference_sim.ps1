# Run Inference Testbench Simulation (Windows PowerShell)
#=============================================================================
# Compiles and runs the inference module testbench using iverilog
#
# Usage: .\run_inference_sim.ps1
#
# Author: Tony Korycki
# Date: October 31, 2025
#=============================================================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Inference Module Simulation" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Change to testbench directory
Set-Location $PSScriptRoot

# Check if test vectors exist
if (-not (Test-Path "..\..\models\test_input_hex.txt")) {
    Write-Host "❌ Error: Test vectors not found!" -ForegroundColor Red
    Write-Host "Run: python python/convert_test_vectors.py" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Test vectors found" -ForegroundColor Green
Write-Host ""

# Compile with iverilog
Write-Host "Compiling..." -ForegroundColor Yellow
iverilog -g2012 `
    -o inference_sim.vvp `
    -I ..\rtl `
    tb_inference.v `
    ..\rtl\inference.v

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Compilation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Compilation successful" -ForegroundColor Green
Write-Host ""

# Run simulation
Write-Host "Running simulation..." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
vvp inference_sim.vvp

# Check if VCD was generated
if (Test-Path "inference_tb.vcd") {
    Write-Host ""
    Write-Host "✅ Waveform saved to: inference_tb.vcd" -ForegroundColor Green
    Write-Host "   View with: gtkwave inference_tb.vcd" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Simulation complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
