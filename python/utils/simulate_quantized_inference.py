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

    print(f"Loaded quantized model from {model_dir}")
    print(f"Dataset: {X.shape[0]} samples, {X.shape[1]} features")
    print(f"Model has {len(scales['layers'])} layers")

    preds = []
    logits = []
    for i, x in enumerate(X):
        pred, logit = int_inference(x, weights, scales)
        preds.append(pred)
        logits.append(logit)
        
        if i % 1000 == 0:
            print(f"Processed {i}/{len(X)} samples...")

    preds = np.array(preds)
    logits = np.array(logits)
    acc = np.mean(preds == y)
    print(f"\nQuantized accuracy: {acc * 100:.2f}%")

    # Misclassified samples
    mis_idx = np.where(preds != y)[0]
    print(f"Misclassified: {len(mis_idx)} / {len(y)}")
    if len(mis_idx) > 0:
        print("First 10 misclassifications:")
        for i in mis_idx[:10]:
            print(f"  {filenames[i]} -> true: {y[i]}, pred: {preds[i]}")

    # Save misclassified list
    with open(os.path.join(model_dir, "misclassified.txt"), "w") as f:
        for i in mis_idx:
            f.write(f"{filenames[i]}\ttrue:{y[i]}\tpred:{preds[i]}\n")
    
    # Validate against golden test vectors (from float model)
    test_input_path = os.path.join(model_dir, "test_input.npy")
    test_output_path = os.path.join(model_dir, "test_output.npy")
    
    if os.path.exists(test_input_path) and os.path.exists(test_output_path):
        print(f"\nValidating against golden test vectors...")
        X_test = np.load(test_input_path)
        y_golden = np.load(test_output_path)  # Float model predictions
        
        test_preds = []
        test_logits = []
        for x in X_test:
            pred, logit = int_inference(x, weights, scales)
            test_preds.append(pred)
            test_logits.append(logit)
        
        test_preds = np.array(test_preds)
        test_logits = np.array(test_logits)
        
        # Compare quantized vs float predictions
        matches = np.sum(test_preds == y_golden)
        print(f"Test vector agreement: {matches}/{len(y_golden)} ({matches/len(y_golden)*100:.1f}%)")
        
        # Save test logits for debugging
        np.save(os.path.join(model_dir, "test_logits.npy"), test_logits)
        print(f"Saved test logits to {model_dir}/test_logits.npy")
    else:
        print(f"\nNo golden test vectors found. Run train_model.py first to generate them.")


if __name__ == "__main__":
    main()
