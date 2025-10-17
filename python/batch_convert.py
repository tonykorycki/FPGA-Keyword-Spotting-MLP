#!/usr/bin/env python
"""Batch convert WAV files from preprocessed/ to processed/ folders.

This script takes all WAV files from data/preprocessed/{start,silence,noise}
and converts them to 16 kHz, 16-bit PCM, mono WAV files in the
corresponding data/processed/ folders.

Usage:
    python batch_convert.py [--force]

Options:
    --force     Overwrite existing files in processed/ folders

The script uses the resample_wav.py module for conversion.
"""

import os
import sys
import glob
import argparse
from pathlib import Path
from resample_wav import resample_and_write

# Setup paths
ROOT_DIR = Path(__file__).resolve().parent.parent
PREPROC_DIR = ROOT_DIR / "data" / "preprocessed"
PROC_DIR = ROOT_DIR / "data" / "processed"
CLASSES = ["start", "silence", "noise"]

def process_folder(class_name, force=False):
    """Process all WAVs in one class folder."""
    in_dir = PREPROC_DIR / class_name
    out_dir = PROC_DIR / class_name
    
    # Ensure output directory exists
    os.makedirs(out_dir, exist_ok=True)
    
    # Get all wav files
    wav_files = list(in_dir.glob("*.wav"))
    if not wav_files:
        print(f"No WAV files found in {in_dir}")
        return 0
    
    processed = 0
    for wav_file in wav_files:
        out_file = out_dir / wav_file.name
        
        # Skip if output exists and not forcing
        if out_file.exists() and not force:
            print(f"Skipping {wav_file.name} (already exists, use --force to overwrite)")
            continue
        
        print(f"Converting {wav_file.name}...")
        try:
            resample_and_write(str(wav_file), str(out_file))
            processed += 1
        except Exception as e:
            print(f"Error converting {wav_file.name}: {e}")
    
    return processed

def main():
    parser = argparse.ArgumentParser(description="Batch convert WAV files to standard format")
    parser.add_argument("--force", action="store_true", help="Overwrite existing files")
    args = parser.parse_args()
    
    # Check if folders exist
    if not PREPROC_DIR.exists():
        print(f"Error: Preprocessed directory not found: {PREPROC_DIR}")
        sys.exit(1)
    
    total_processed = 0
    for class_name in CLASSES:
        class_dir = PREPROC_DIR / class_name
        if not class_dir.exists():
            print(f"Warning: Class directory not found: {class_dir}")
            continue
        
        print(f"\nProcessing {class_name} files...")
        processed = process_folder(class_name, args.force)
        print(f"Processed {processed} files for {class_name}")
        total_processed += processed
    
    print(f"\nTotal: {total_processed} files converted to 16 kHz, 16-bit PCM, mono WAV")
    
    if total_processed == 0:
        print(f"\nHINT: Place your raw recordings in the following folders:")
        for class_name in CLASSES:
            print(f"  - {PREPROC_DIR / class_name}")

if __name__ == "__main__":
    main()