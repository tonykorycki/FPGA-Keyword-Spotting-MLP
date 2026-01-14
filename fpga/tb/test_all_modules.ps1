#!/usr/bin/env pwsh
# Test all FPGA-KWS modules systematically
# Author: Tony Korycki
# Date: January 14, 2026

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "   FPGA-KWS Module Testing Suite" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$ErrorActionPreference = "Continue"
$testsPassed = 0
$testsFailed = 0

# Helper function to run Icarus Verilog simulation
function Run-IcarusTest {
    param(
        [string]$TestName,
        [string]$Testbench,
        [string[]]$Sources,
        [string]$WorkDir = "fpga/tb"
    )
    
    Write-Host "`n[TEST] $TestName" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor DarkGray
    
    Push-Location $WorkDir
    
    # Compile
    Write-Host "  Compiling..." -ForegroundColor Gray
    $cmd = "iverilog -g2012 -o ${TestName}.vvp $Testbench"
    foreach ($src in $Sources) {
        $cmd += " $src"
    }
    
    Write-Host "  CMD: $cmd" -ForegroundColor DarkGray
    Invoke-Expression $cmd
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] Compilation failed" -ForegroundColor Red
        $script:testsFailed++
        Pop-Location
        return $false
    }
    
    # Run simulation
    Write-Host "  Running simulation..." -ForegroundColor Gray
    vvp "${TestName}.vvp"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] $TestName completed successfully" -ForegroundColor Green
        $script:testsPassed++
        Pop-Location
        return $true
    } else {
        Write-Host "  [FAIL] $TestName failed" -ForegroundColor Red
        $script:testsFailed++
        Pop-Location
        return $false
    }
}

# Change to project root
Set-Location $PSScriptRoot/../..

Write-Host "`nStarting module tests..." -ForegroundColor White

# Test 1: Frame Buffer
Run-IcarusTest `
    -TestName "frame_buffer" `
    -Testbench "tb_frame_buffer.v" `
    -Sources @("../rtl/frame_buffer.v")

# Test 2: Feature Extractor (CRITICAL - just fixed scaling!)
Run-IcarusTest `
    -TestName "feature_extractor" `
    -Testbench "tb_feature_extractor.v" `
    -Sources @("../rtl/feature_extractor.v")

# Test 3: Feature Averager
Run-IcarusTest `
    -TestName "feature_averager" `
    -Testbench "tb_feature_averager.v" `
    -Sources @("../rtl/feature_averager.v")

# Test 4: Inference Engine (should still pass - weights already quantized)
Write-Host "`n[TEST] Inference Engine" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "  Using existing test script..." -ForegroundColor Gray
Set-Location fpga/tb
& .\run_inference_sim.ps1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [PASS] Inference engine test passed" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  [FAIL] Inference engine test failed" -ForegroundColor Red
    $testsFailed++
}
Set-Location ../..

# Summary
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "   Test Summary" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Failed: $testsFailed" -ForegroundColor Red
Write-Host "  Total:  $($testsPassed + $testsFailed)" -ForegroundColor White

if ($testsFailed -eq 0) {
    Write-Host "`n  All tests passed! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n  Some tests failed. Check output above." -ForegroundColor Red
    exit 1
}
