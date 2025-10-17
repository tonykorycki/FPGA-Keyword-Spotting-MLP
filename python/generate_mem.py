#!/usr/bin/env python3
"""
Keyword Spotting System - Memory File Generation Script
Author: 
Date: October 17, 2025

This script generates memory initialization files for the FPGA
from the quantized model weights.
"""

import os
import argparse
import numpy as np

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Generate memory initialization files")
    parser.add_argument("--weights_dir", type=str, default="../models/quantized",
                       help="Directory containing quantized weights")
    parser.add_argument("--output_dir", type=str, default="../fpga/rtl/memory",
                       help="Directory to save memory initialization files")
    parser.add_argument("--format", type=str, choices=["hex", "bin", "coe", "mif"], default="hex",
                       help="Format of memory initialization files")
    return parser.parse_args()

def ensure_dir(directory):
    """Create directory if it doesn't exist."""
    if not os.path.exists(directory):
        os.makedirs(directory)

def convert_to_memory_format(weights, format_type):
    """Convert weights to specified memory format."""
    if format_type == "hex":
        # Convert to hexadecimal format
        if weights.ndim == 1:
            # 1D array (bias)
            return [f"{(w & 0xFF):02x}" for w in weights]
        else:
            # 2D array (weight matrix)
            return [[f"{(w & 0xFF):02x}" for w in row] for row in weights]
    elif format_type == "bin":
        # Convert to binary format
        if weights.ndim == 1:
            # 1D array (bias)
            return [f"{(w & 0xFF):08b}" for w in weights]
        else:
            # 2D array (weight matrix)
            return [[f"{(w & 0xFF):08b}" for w in row] for row in weights]
    elif format_type == "coe":
        # Return as integer values for COE format
        return weights
    elif format_type == "mif":
        # Return as integer values for MIF format
        return weights
    else:
        raise ValueError(f"Unsupported format: {format_type}")

def write_memory_file(filename, data, format_type):
    """Write memory initialization file in specified format."""
    with open(filename, "w") as f:
        if format_type == "hex":
            for item in data:
                if isinstance(item, list):
                    f.write(" ".join(item) + "\n")
                else:
                    f.write(item + "\n")
        elif format_type == "bin":
            for item in data:
                if isinstance(item, list):
                    f.write(" ".join(item) + "\n")
                else:
                    f.write(item + "\n")
        elif format_type == "coe":
            f.write("memory_initialization_radix=16;\n")
            f.write("memory_initialization_vector=\n")
            if data.ndim == 1:
                values = [f"{(w & 0xFF):02x}" for w in data]
                f.write(",\n".join(values) + ";\n")
            else:
                rows = []
                for row in data:
                    values = [f"{(w & 0xFF):02x}" for w in row]
                    rows.append(",".join(values))
                f.write(",\n".join(rows) + ";\n")
        elif format_type == "mif":
            f.write("-- Memory Initialization File\n")
            f.write("WIDTH=8;\n")
            if data.ndim == 1:
                f.write(f"DEPTH={len(data)};\n")
            else:
                f.write(f"DEPTH={data.shape[0] * data.shape[1]};\n")
            f.write("ADDRESS_RADIX=HEX;\n")
            f.write("DATA_RADIX=HEX;\n")
            f.write("CONTENT BEGIN\n")
            
            address = 0
            if data.ndim == 1:
                for w in data:
                    f.write(f"  {address:04x} : {(w & 0xFF):02x};\n")
                    address += 1
            else:
                for row in data:
                    for w in row:
                        f.write(f"  {address:04x} : {(w & 0xFF):02x};\n")
                        address += 1
            
            f.write("END;\n")

def main():
    args = parse_args()
    
    # Create output directory
    ensure_dir(args.output_dir)
    
    # Load quantized weights
    weight_files = sorted([f for f in os.listdir(args.weights_dir) if f.startswith("weight")])
    
    print(f"Found {len(weight_files)} weight files")
    
    for i, file in enumerate(weight_files):
        # Load weights
        weights = np.load(os.path.join(args.weights_dir, file))
        
        print(f"Processing {file}, shape: {weights.shape}")
        
        # Convert to memory format
        formatted_weights = convert_to_memory_format(weights, args.format)
        
        # Determine output filename
        base_name = os.path.splitext(file)[0]
        output_file = os.path.join(args.output_dir, f"{base_name}.{args.format}")
        
        # Write memory file
        write_memory_file(output_file, weights, args.format)
        
        print(f"Generated memory file: {output_file}")
    
    print("\nMemory file generation complete!")

if __name__ == "__main__":
    main()