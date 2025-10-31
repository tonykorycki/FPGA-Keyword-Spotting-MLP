#!/bin/bash
#=============================================================================
# Run Inference Testbench Simulation
#=============================================================================
# Compiles and runs the inference module testbench using iverilog
#
# Usage: ./run_inference_sim.sh
#
# Author: Tony Korycki
# Date: October 31, 2025
#=============================================================================

echo "========================================="
echo "Inference Module Simulation"
echo "========================================="
echo ""

# Change to testbench directory
cd "$(dirname "$0")"

# Check if test vectors exist
if [ ! -f "../../models/test_input_hex.txt" ]; then
    echo "❌ Error: Test vectors not found!"
    echo "Run: python python/convert_test_vectors.py"
    exit 1
fi

echo "✅ Test vectors found"
echo ""

# Compile with iverilog
echo "Compiling..."
iverilog -g2012 \
    -o inference_sim \
    -I ../rtl \
    tb_inference.v \
    ../rtl/inference.v

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed!"
    exit 1
fi

echo "✅ Compilation successful"
echo ""

# Run simulation
echo "Running simulation..."
echo "========================================="
vvp inference_sim

# Check if VCD was generated
if [ -f "inference_tb.vcd" ]; then
    echo ""
    echo "✅ Waveform saved to: inference_tb.vcd"
    echo "   View with: gtkwave inference_tb.vcd"
fi

echo ""
echo "========================================="
echo "Simulation complete!"
echo "========================================="
