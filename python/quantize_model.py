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


def quantize_model(model_path, output_dir="models"):
    model = keras.models.load_model(model_path)
    layers = [l for l in model.layers if len(l.get_weights()) > 0]
    quant_data = {}
    scale_info = {
        "input_scale": 1.0 / 127.0,
        "layers": []
    }

    print(f"🔧 Quantizing model from {model_path}")

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
        
        print(f"  Layer {i} ({layer.name}):")
        print(f"    Weights: {w_q.shape}, range=[{w_q.min()}, {w_q.max()}]")
        print(f"    w_scale={w_scale:.6e}, in_scale={input_scale:.6e}, out_scale={output_scale:.6e}")
        
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

    print(f"✅ Quantized files saved to {output_dir}/")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Quantize a trained KWS model for FPGA inference")
    parser.add_argument("--model", type=str, default="models/kws_model.h5", help="Path to trained .h5 model")
    parser.add_argument("--output_dir", type=str, default="models", help="Directory to save quantized files")
    args = parser.parse_args()
    quantize_model(args.model, args.output_dir)
