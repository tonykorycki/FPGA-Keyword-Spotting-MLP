#!/usr/bin/env python3
"""
Combine all weight memory files into a single unified BRAM file.

Address layout:
  0-8223:     layer0_weights (257×32 = 8,224 entries)
  8224-8735:  layer1_weights (32×16 = 512 entries)
  8736-8767:  layer2_weights (16×2 = 32 entries)
  
Total: 8,768 weights (8-bit each)
"""

import os

# Get the directory where this script is located
script_dir = os.path.dirname(os.path.abspath(__file__))

# Read all weight files
def read_mem_file(filename):
    """Read a .mem file and return list of hex values."""
    filepath = os.path.join(script_dir, filename)
    with open(filepath, 'r') as f:
        lines = [line.strip() for line in f if line.strip()]
    return lines

# Read individual weight files
layer0_weights = read_mem_file('layer0_weights.mem')
layer1_weights = read_mem_file('layer1_weights.mem')
layer2_weights = read_mem_file('layer2_weights.mem')

print(f"Layer 0 weights: {len(layer0_weights)} entries (expected 8224)")
print(f"Layer 1 weights: {len(layer1_weights)} entries (expected 512)")
print(f"Layer 2 weights: {len(layer2_weights)} entries (expected 32)")

# Combine into single file
combined = layer0_weights + layer1_weights + layer2_weights

print(f"Total combined: {len(combined)} entries (expected 8768)")

# Write combined file
output_path = os.path.join(script_dir, 'weights_combined.mem')
with open(output_path, 'w') as f:
    for val in combined:
        f.write(val + '\n')

print(f"Written to: {output_path}")

# Verify addresses
print(f"\nAddress layout:")
print(f"  Layer 0: 0 - {len(layer0_weights)-1}")
print(f"  Layer 1: {len(layer0_weights)} - {len(layer0_weights) + len(layer1_weights) - 1}")
print(f"  Layer 2: {len(layer0_weights) + len(layer1_weights)} - {len(combined) - 1}")
