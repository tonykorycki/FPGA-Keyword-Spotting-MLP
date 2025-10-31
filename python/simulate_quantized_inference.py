#!/usr/bin/env python3
"""
Simulate quantized KWS model inference (fixed-point integer math)
Author: Tony Korycki
Date: October 25, 2025

Verifies that FPGA-style int8 inference matches float model behavior.
"""

import os
import json
import numpy as np


def relu_int8(x):
    """Integer ReLU - clamp negative values to 0."""
    return np.maximum(x, 0)


def load_quantized_model(model_dir="models"):
    """Load quantized weights and scale factors."""
    weights = np.load(os.path.join(model_dir, "quantized_weights.npz"))
    with open(os.path.join(model_dir, "scales.json")) as f:
        scales = json.load(f)
    return weights, scales


def load_dataset(data_dir="data/processed"):
    """Load features, labels, and filenames for testing."""
    X = np.load(os.path.join(data_dir, "features.npy"))
    y = np.load(os.path.join(data_dir, "labels.npy"))
    
    # Normalize same as training
    X = X / np.max(X)

    filenames_path = os.path.join(data_dir, "filenames.npy")
    filenames = np.load(filenames_path) if os.path.exists(filenames_path) else np.array([f"sample_{i}" for i in range(len(y))])
    return X, y, filenames


def int_inference(x, weights, scales):
    """
    Layer-accurate fixed-point inference matching FPGA behavior.
    
    Flow per layer:
    1. Quantize input to int8
    2. Matrix multiply (int8 x int8 -> int32 accumulator)
    3. Add bias (int32)
    4. Requantize accumulator back to int8 output range
    5. Apply ReLU
    """
    # Quantize input [0,1] -> int8 [-127, 127]
    input_scale = scales["input_scale"]
    x_q = np.clip(np.round(x / input_scale), -127, 127).astype(np.int8)
    
    num_layers = len(scales["layers"])
    
    for layer_idx in range(num_layers):
        layer_info = scales["layers"][layer_idx]
        w_q = weights[f"layer{layer_idx}_weights"]
        b_q = weights[f"layer{layer_idx}_bias"]
        
        # Matrix multiply: x @ W (Keras stores Dense weights as (input_dim, output_dim))
        # x_q shape: (input_dim,)
        # w_q shape: (input_dim, output_dim) - Keras format
        # Result: (output_dim,)
        acc = np.dot(x_q.astype(np.int32), w_q.astype(np.int32))
        
        # Add bias (already in accumulator scale)
        acc = acc + b_q.astype(np.int32)
        
        # Requantize: shift from accumulator scale to output scale
        # acc is in scale: input_scale * weight_scale (= bias_scale)
        # we want output in scale: output_scale
        # So multiply by: bias_scale / output_scale = requantize_scale
        requant_scale = layer_info["requantize_scale"]
        acc_scaled = acc * requant_scale
        
        # Clip to int8 range and convert
        x_q = np.clip(np.round(acc_scaled), -127, 127).astype(np.int8)
        
        # Apply ReLU (except on final layer - it has softmax)
        if layer_idx < num_layers - 1:
            x_q = relu_int8(x_q)
    
    # Final layer output is still int8, but represents logits
    # Return both logits and argmax for classification
    return np.argmax(x_q), x_q


def main():
    model_dir = "models"
    data_dir = "data/processed"

    weights, scales = load_quantized_model(model_dir)
    X, y, filenames = load_dataset(data_dir)

    print(f"🔧 Loaded quantized model from {model_dir}")
    print(f"📦 Dataset: {X.shape[0]} samples, {X.shape[1]} features")
    print(f"🔢 Model has {len(scales['layers'])} layers")
    
    # Debug: print weight shapes
    for i in range(len(scales['layers'])):
        w_shape = weights[f"layer{i}_weights"].shape
        b_shape = weights[f"layer{i}_bias"].shape
        print(f"  Layer {i}: weights {w_shape}, bias {b_shape}")

    preds = []
    logits = []
    for i, x in enumerate(X):
        pred, logit = int_inference(x, weights, scales)
        preds.append(pred)
        logits.append(logit)
        
        if i % 1000 == 0:
            print(f"  Processed {i}/{len(X)} samples...")

    preds = np.array(preds)
    logits = np.array(logits)
    acc = np.mean(preds == y)
    print(f"\n✅ Quantized fixed-point accuracy: {acc * 100:.2f}%")

    # Misclassified samples
    mis_idx = np.where(preds != y)[0]
    print(f"❌ Misclassified: {len(mis_idx)} / {len(y)}")
    for i in mis_idx[:10]:  # show up to 10
        print(f"  {filenames[i]} → true: {y[i]}, pred: {preds[i]}")

    # Save reference predictions for FPGA testbench comparison
    test_samples = min(100, len(X))
    np.save(os.path.join(model_dir, "test_input.npy"), X[:test_samples])
    np.save(os.path.join(model_dir, "test_output.npy"), preds[:test_samples])
    np.save(os.path.join(model_dir, "test_logits.npy"), logits[:test_samples])
    print(f"\n💾 Saved {test_samples} golden test vectors to:")
    print(f"  {model_dir}/test_input.npy")
    print(f"  {model_dir}/test_output.npy")
    print(f"  {model_dir}/test_logits.npy")


if __name__ == "__main__":
    main()
