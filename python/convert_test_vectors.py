#!/usr/bin/env python3
"""
Convert test vectors to Verilog-readable hex format
Author: Tony Korycki
Date: October 31, 2025

Loads test_input.npy and test_output.npy
Converts to hex format for Verilog testbench
"""

import numpy as np
import os

def main():
    model_dir = "models"
    
    # Load test data
    X = np.load(os.path.join(model_dir, "test_input.npy"))
    y = np.load(os.path.join(model_dir, "test_output.npy"))
    
    print(f"Loaded {X.shape[0]} test samples")
    print(f"Feature shape: {X.shape}")
    print(f"Output shape: {y.shape}")
    
    # Load scales for quantization
    import json
    with open(os.path.join(model_dir, "scales.json")) as f:
        scales = json.load(f)
    
    input_scale = scales["input_scale"]
    
    # Quantize inputs to int8 (same as inference module expects)
    X_q = np.clip(np.round(X / input_scale), -127, 127).astype(np.int8)
    
    # Convert to unsigned hex for Verilog (avoid overflow by using uint8)
    X_hex = X_q.astype(np.uint8)  # Automatically handles two's complement
    
    # Write input features
    with open(os.path.join(model_dir, "test_input_hex.txt"), "w") as f:
        for sample in X_hex:
            for feature in sample:
                f.write(f"{feature:02x}\n")
    
    print(f"✅ Wrote test_input_hex.txt ({X_hex.shape[0]} samples × {X_hex.shape[1]} features)")
    
    # Write expected outputs
    with open(os.path.join(model_dir, "test_output_ref.txt"), "w") as f:
        for pred in y:
            f.write(f"{int(pred)}\n")
    
    print(f"✅ Wrote test_output_ref.txt ({len(y)} predictions)")
    
    # Print some statistics
    print(f"\nInput statistics:")
    print(f"  Float range: [{X.min():.3f}, {X.max():.3f}]")
    print(f"  Quantized range: [{X_q.min()}, {X_q.max()}]")
    print(f"  Input scale: {input_scale:.6e}")
    print(f"\nOutput distribution:")
    print(f"  Class 0: {np.sum(y == 0)} samples")
    print(f"  Class 1: {np.sum(y == 1)} samples")
    
    # Show first sample
    print(f"\nFirst sample (first 10 features):")
    print(f"  Float: {X[0, :10]}")
    print(f"  Int8:  {X_q[0, :10]}")
    print(f"  Hex:   {[f'{v:02x}' for v in X_hex[0, :10]]}")
    print(f"  Expected output: {y[0]}")

if __name__ == "__main__":
    main()
