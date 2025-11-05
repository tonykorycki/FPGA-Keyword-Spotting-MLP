#!/usr/bin/env python3
"""
Layer-by-layer diagnostic comparison between float and quantized KWS model
Author: Tony Korycki
Date: October 26, 2025

Checks how each dense layer behaves after quantization.
"""

import os
import json
import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt
import keras
from typing import cast
from matplotlib.axes import Axes


def relu(x):
    return np.maximum(x, 0)


def load_quantized(model_dir="models"):
    """Load quantized weights and per-layer scales."""
    data = np.load(os.path.join(model_dir, "quantized_weights.npz"))
    with open(os.path.join(model_dir, "scales.json")) as f:
        scales = json.load(f)
    return data, scales


def forward_float(model, x):
    """Extract float layer outputs using TensorFlow."""
    outputs = []
    temp = x
    for layer in model.layers:
        temp = layer(temp)
        outputs.append(np.array(temp)[0])  # Remove batch dimension
    return outputs


def forward_quantized(x, weights, scales):
    """
    Layer-by-layer quantized inference with proper scale handling.
    Returns both intermediate activations for debugging.
    """
    # Quantize input
    input_scale = scales["input_scale"]
    x_q = np.clip(np.round(x / input_scale), -127, 127).astype(np.int8)
    
    outputs = []
    num_layers = len(scales["layers"])
    
    for layer_idx in range(num_layers):
        layer_info = scales["layers"][layer_idx]
        w_q = weights[f"layer{layer_idx}_weights"]
        b_q = weights[f"layer{layer_idx}_bias"]
        
        # Matrix multiply (int8 x int8 -> int32)
        acc = np.dot(x_q.astype(np.int32), w_q.astype(np.int32))
        
        # Add bias
        acc = acc + b_q.astype(np.int32)
        
        # Convert to float for comparison (what the float value would be)
        # acc is in scale: input_scale * weight_scale
        acc_float = acc * layer_info["bias_scale"]
        outputs.append(("pre_relu", acc_float.copy()))
        
        # Requantize to int8
        requant_scale = layer_info["requantize_scale"]
        acc_scaled = acc * requant_scale
        x_q = np.clip(np.round(acc_scaled), -127, 127).astype(np.int8)
        
        # Apply ReLU (except on final layer)
        if layer_idx < num_layers - 1:
            x_q = np.maximum(x_q, 0)
            # Convert to float for comparison
            post_relu_float = x_q.astype(np.float32) * layer_info["output_scale"]
            outputs.append(("post_relu", post_relu_float.copy()))
    
    # Final output (logits, no ReLU)
    final_float = x_q.astype(np.float32) * scales["layers"][-1]["output_scale"]
    outputs.append(("final", final_float))
    
    return outputs


def main():
    model_dir = "models"
    data_dir = "data/processed"

    print("Loading models and data...")
    float_model = keras.models.load_model(os.path.join(model_dir, "kws_model.h5"))
    weights_q, scales = load_quantized(model_dir)

    X = np.load(os.path.join(data_dir, "features.npy"))
    y = np.load(os.path.join(data_dir, "labels.npy"))
    X = X / np.max(X)  # Same normalization as training
    
    filenames_path = os.path.join(data_dir, "filenames.npy")
    if os.path.exists(filenames_path):
        filenames = np.load(filenames_path, allow_pickle=True)
    else:
        filenames = [f"sample_{i}" for i in range(len(y))]
    
    sample_idx = 0  # you can change this
    x = X[sample_idx:sample_idx + 1]
    y_true = y[sample_idx]

    print(f"\nSample: {filenames[sample_idx]}, true label = {y_true}")

    # --- Float path ---
    float_outputs = forward_float(float_model, x)
    float_pred = np.argmax(float_outputs[-1])

    # --- Quantized path ---
    quant_outputs = forward_quantized(x[0], weights_q, scales)
    quant_pred = np.argmax(quant_outputs[-1][1])

    print(f"Float prediction = {float_pred}, Quantized = {quant_pred}")

    # --- Layer comparison ---
    print("\nLayer output comparison:")
    print(f"{'Layer':<20} {'Type':<12} {'MAE':<12} {'Max Diff':<12}")
    print("-" * 60)
    
    # Match float and quantized outputs
    float_idx = 0
    for i, (stage, q_out) in enumerate(quant_outputs):
        if stage == "final":
            f_out = float_outputs[-1]
        else:
            # Match pre/post ReLU outputs
            f_out = float_outputs[float_idx]
            if stage == "post_relu":
                float_idx += 1
        
        mae = np.mean(np.abs(f_out - q_out))
        max_diff = np.max(np.abs(f_out - q_out))
        print(f"Layer {i//2:<14} {stage:<12} {mae:<12.6f} {max_diff:<12.6f}")
        
        if stage == "post_relu":
            float_idx += 1

    num_plots = len(quant_outputs)
    fig, axes = plt.subplots(num_plots, 1, figsize=(12, 3 * num_plots))
    if num_plots == 1:
        axes = [axes]
    
    float_idx = 0
    for i, (stage, q_out) in enumerate(quant_outputs):
        ax = cast(Axes, axes[i])
        
        # Get corresponding float output
        if stage == "final":
            f_out = float_outputs[-1]
            title = "Final Output (Logits)"
        else:
            f_out = float_outputs[float_idx]
            title = f"Layer {i//2} - {stage.replace('_', ' ').title()}"
            if stage == "post_relu":
                float_idx += 1
        
        # Plot
        x_axis = np.arange(len(q_out))
        ax.plot(x_axis, f_out, 'b-', label='Float', alpha=0.7, linewidth=2)
        ax.plot(x_axis, q_out, 'r--', label='Quantized', alpha=0.7, linewidth=2)
        ax.set_title(title)
        ax.set_xlabel('Neuron Index')
        ax.set_ylabel('Activation Value')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        if stage == "post_relu":
            float_idx += 1
    
    plt.tight_layout()
    
    plt.tight_layout()
    plt.savefig(os.path.join(model_dir, "layer_comparison.png"), dpi=150)
    print(f"\nSaved comparison plot to {model_dir}/layer_comparison.png")
    plt.show()


if __name__ == "__main__":
    main()
