#!/usr/bin/env python3
"""
Keyword Spotting System - Model Quantization Script
Author: 
Date: October 17, 2025

This script quantizes the trained model to fixed-point format
suitable for FPGA implementation.
"""

import os
import argparse
import numpy as np
import tensorflow as tf
# Import keras directly - this is the recommended way in TF 2.19+
import keras
from keras import layers, models
import matplotlib.pyplot as plt

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Quantize KWS model")
    parser.add_argument("--model_path", type=str, default="../models/kws_model.h5",
                       help="Path to the trained model")
    parser.add_argument("--features_dir", type=str, default="../data/features",
                       help="Directory containing extracted features for validation")
    parser.add_argument("--output_dir", type=str, default="../models/quantized",
                       help="Directory to save quantized model")
    parser.add_argument("--bits", type=int, default=8,
                       help="Number of bits for quantization")
    parser.add_argument("--validate", action="store_true",
                       help="Validate quantized model accuracy")
    return parser.parse_args()

def ensure_dir(directory):
    """Create directory if it doesn't exist."""
    if not os.path.exists(directory):
        os.makedirs(directory)

def quantize_weights(weights, bits=8):
    """Quantize model weights to fixed-point representation."""
    # Determine the maximum absolute value in the weights
    abs_max = np.max(np.abs(weights))
    
    # Determine the scale factor for quantization
    scale = (2**(bits-1) - 1) / abs_max if abs_max > 0 else 1
    
    # Quantize the weights
    quantized = np.round(weights * scale)
    
    # Clip to ensure we're within bounds
    quantized = np.clip(quantized, -2**(bits-1), 2**(bits-1) - 1)
    
    return quantized, scale

def quantize_model(model, bits=8):
    """Quantize all weights in the model."""
    quantized_weights = []
    scales = []
    
    # Process each layer in the model
    for layer in model.layers:
        if isinstance(layer, layers.Dense):
            # Quantize weights
            weights, weight_scale = quantize_weights(layer.get_weights()[0], bits)
            quantized_weights.append(weights)
            scales.append(weight_scale)
            
            # Quantize biases (with same scale as weights for simplicity)
            biases, bias_scale = quantize_weights(layer.get_weights()[1], bits)
            quantized_weights.append(biases)
            scales.append(bias_scale)
    
    return quantized_weights, scales

def validate_quantization(model, quantized_weights, scales, X_test, y_test):
    """Validate the quantized model by comparing with original model."""
    # Original model prediction
    original_pred = np.argmax(model.predict(X_test), axis=-1)
    
    # Manually implement forward pass with quantized weights
    # This is a simplified version that only works for our specific architecture
    quantized_pred = []
    
    for i in range(len(X_test)):
        # Get the input sample
        x = X_test[i].flatten()
        
        # Layer 1: Dense with ReLU
        z1 = np.dot(x, quantized_weights[0] / scales[0]) + quantized_weights[1] / scales[1]
        a1 = np.maximum(0, z1)  # ReLU activation
        
        # Layer 2: Dense with Softmax
        z2 = np.dot(a1, quantized_weights[2] / scales[2]) + quantized_weights[3] / scales[3]
        exp_z2 = np.exp(z2 - np.max(z2))  # Subtract max for numerical stability
        a2 = exp_z2 / np.sum(exp_z2)  # Softmax activation
        
        # Get predicted class
        pred = np.argmax(a2)
        quantized_pred.append(pred)
    
    # Calculate accuracy
    original_acc = np.mean(original_pred == y_test)
    quantized_acc = np.mean(quantized_pred == y_test)
    
    # Calculate agreement between original and quantized model
    agreement = np.mean(original_pred == quantized_pred)
    
    return {
        'original_acc': original_acc,
        'quantized_acc': quantized_acc,
        'agreement': agreement
    }

def main():
    args = parse_args()
    
    # Create output directory
    ensure_dir(args.output_dir)
    
    # Load the model
    print(f"Loading model from {args.model_path}")
    model = models.load_model(args.model_path)
    if model is None:
        print("Error: Failed to load the model.")
        exit(1)
    model.summary()
    
    # Quantize the model
    print(f"\nQuantizing model to {args.bits}-bit precision")
    quantized_weights, scales = quantize_model(model, bits=args.bits)
    
    # Save quantized weights
    for i, (qw, scale) in enumerate(zip(quantized_weights, scales)):
        weight_file = os.path.join(args.output_dir, f"weight_{i}.npy")
        np.save(weight_file, qw.astype(np.int8))
        print(f"Saved quantized weight {i} to {weight_file}, shape: {qw.shape}, scale: {scale:.4f}")
    
    # Save scales
    scale_file = os.path.join(args.output_dir, "scales.npy")
    np.save(scale_file, np.array(scales))
    print(f"Saved quantization scales to {scale_file}")
    
    # Validate if requested
    if args.validate:
        print("\nValidating quantized model...")
        
        # Load test data
        X_test = np.load(os.path.join(args.features_dir, "features.npy"))
        y_test = np.load(os.path.join(args.features_dir, "labels.npy"))
        
        # Use a subset for validation to speed things up
        X_test = X_test[:100]
        y_test = y_test[:100]
        
        # Validate
        results = validate_quantization(model, quantized_weights, scales, X_test, y_test)
        
        print(f"Original model accuracy: {results['original_acc']:.4f}")
        print(f"Quantized model accuracy: {results['quantized_acc']:.4f}")
        print(f"Agreement between models: {results['agreement']:.4f}")

if __name__ == "__main__":
    main()