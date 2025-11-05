#!/usr/bin/env python3
"""
Quantize KWS model for FPGA inference
Author: Tony Korycki
Date: October 25, 2025

Loads a trained .h5 model and exports:
- quantized_weights.npz (int8/16 arrays)
- scales.json (float scaling factors)
- mem/ directory with .mem files for Verilog
"""

import os
import json
import numpy as np
import tensorflow as tf
import keras


def to_mem(array, path):
    """Save a numpy array as a .mem hex file for Verilog."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        for val in array.flatten():
            v = int(val)
            # Handle signed int8/int32 as unsigned hex
            if val.dtype == np.int8:
                if v < 0:
                    v = (1 << 8) + v
                f.write(f"{v & 0xFF:02x}\n")
            else:  # int32
                if v < 0:
                    v = (1 << 32) + v
                f.write(f"{v & 0xFFFFFFFF:08x}\n")


def save_verilog_test_vectors(X_test, y_test, input_scale, output_dir="models"):
    """Convert test vectors to Verilog-readable hex format for testbench."""
    print(f"\nConverting test vectors to Verilog hex format...")
    
    # Quantize inputs to int8 (same as inference module expects)
    X_q = np.clip(np.round(X_test / input_scale), -127, 127).astype(np.int8)
    
    # Convert to unsigned hex for Verilog (handles two's complement)
    X_hex = X_q.astype(np.uint8)
    
    # Write input features
    input_file = os.path.join(output_dir, "test_input_hex.txt")
    with open(input_file, "w") as f:
        for sample in X_hex:
            for feature in sample:
                f.write(f"{feature:02x}\n")
    
    # Write expected outputs
    output_file = os.path.join(output_dir, "test_output_ref.txt")
    with open(output_file, "w") as f:
        for pred in y_test:
            f.write(f"{int(pred)}\n")
    
    print(f"Saved {X_hex.shape[0]} test vectors: test_input_hex.txt, test_output_ref.txt")


def quantize_model(model_path, output_dir="models"):
    model = keras.models.load_model(model_path)
    layers = [l for l in model.layers if len(l.get_weights()) > 0]
    quant_data = {}
    scale_info = {
        "input_scale": 1.0 / 127.0,
        "layers": []
    }

    print(f"Quantizing model from {model_path}")

    # Input scale (features are normalized to [0,1])
    input_scale = 1.0 / 127.0
    
    for i, layer in enumerate(layers):
        w, b = layer.get_weights()
        
        # Weight quantization to int8
        w_max = np.max(np.abs(w))
        w_scale = w_max / 127.0
        w_q = np.clip(np.round(w / w_scale), -127, 127).astype(np.int8)
        
        # For FPGA: assume output range matches weight range (conservative)
        # Your validation script should provide better output scales
        output_scale = w_scale
        
        # Bias scale: matches accumulator scale (input * weight)
        bias_scale = input_scale * w_scale
        b_q = np.clip(np.round(b / bias_scale), -2147483648, 2147483647).astype(np.int32)
        
        quant_data[f"layer{i}_weights"] = w_q
        quant_data[f"layer{i}_bias"] = b_q
        
        layer_info = {
            "weight_scale": float(w_scale),
            "input_scale": float(input_scale),
            "output_scale": float(output_scale),
            "bias_scale": float(bias_scale),
            "requantize_scale": float(bias_scale / output_scale)
        }
        scale_info["layers"].append(layer_info)
        
        print(f"Layer {i}: weights {w_q.shape}, range=[{w_q.min()}, {w_q.max()}]")
        
        # Next layer's input is this layer's output
        input_scale = output_scale

    # Save quantized weights
    np.savez(os.path.join(output_dir, "quantized_weights.npz"), **quant_data)
    
    # Save detailed scale information (not just a list)
    with open(os.path.join(output_dir, "scales.json"), "w") as f:
        json.dump(scale_info, f, indent=2)

    # Save .mem files
    mem_dir = os.path.join(output_dir, "mem")
    os.makedirs(mem_dir, exist_ok=True)
    for key, arr in quant_data.items():
        to_mem(arr, os.path.join(mem_dir, f"{key}.mem"))

    print(f"Saved quantized files to {output_dir}/")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Quantize a trained KWS model for FPGA inference")
    parser.add_argument("--model", type=str, default="models/kws_model.h5", help="Path to trained .h5 model")
    parser.add_argument("--output_dir", type=str, default="models", help="Directory to save quantized files")
    parser.add_argument("--test_vectors", action="store_true", help="Also generate Verilog test vectors from test_input.npy")
    args = parser.parse_args()
    
    # Quantize the model
    quantize_model(args.model, args.output_dir)
    
    # Optionally generate Verilog test vectors
    if args.test_vectors:
        test_input_path = os.path.join(args.output_dir, "test_input.npy")
        test_output_path = os.path.join(args.output_dir, "test_output.npy")
        
        if os.path.exists(test_input_path) and os.path.exists(test_output_path):
            X_test = np.load(test_input_path)
            y_test = np.load(test_output_path)
            
            # Load input scale from scales.json
            with open(os.path.join(args.output_dir, "scales.json")) as f:
                scales = json.load(f)
            input_scale = scales["input_scale"]
            
            save_verilog_test_vectors(X_test, y_test, input_scale, args.output_dir)
        else:
            print(f"\nTest files not found. Run train_model.py first to generate test vectors.")
            print(f"Expected: {test_input_path} and {test_output_path}")

