#!/usr/bin/env python3
"""
Keyword Spotting System - Feature Extraction Script
Author: 
Date: October 17, 2025

This script extracts audio features (MFCCs) from the collected audio samples
and prepares the dataset for model training.
"""

import os
import glob
import argparse
import numpy as np
import librosa
import matplotlib.pyplot as plt
from tqdm import tqdm
import pickle

# Constants
SAMPLE_RATE = 16000
N_FFT = 512
HOP_LENGTH = 256
N_MFCC = 32  # Number of MFCC features to extract (matches FPGA design)
FRAME_LENGTH = 512

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Extract features from audio samples")
    parser.add_argument("--input_dir", type=str, default="../data/raw",
                       help="Directory containing raw audio files")
    parser.add_argument("--output_dir", type=str, default="../data/features",
                       help="Directory to save extracted features")
    parser.add_argument("--visualize", action="store_true",
                       help="Visualize the extracted features")
    return parser.parse_args()

def ensure_dir(directory):
    """Create directory if it doesn't exist."""
    if not os.path.exists(directory):
        os.makedirs(directory)

def extract_features(audio_file):
    """Extract MFCC features from audio file."""
    # Load audio file
    y, sr = librosa.load(audio_file, sr=SAMPLE_RATE)
    
    # Apply pre-emphasis filter
    y = librosa.effects.preemphasis(y)
    
    # Extract MFCCs
    mfccs = librosa.feature.mfcc(
        y=y, sr=sr, n_mfcc=N_MFCC, n_fft=N_FFT, hop_length=HOP_LENGTH
    )
    
    # Transpose to get time-major format
    mfccs = mfccs.T
    
    return mfccs

def visualize_features(mfccs, title="MFCC Features"):
    """Visualize the extracted MFCC features."""
    plt.figure(figsize=(10, 4))
    librosa.display.specshow(mfccs.T, x_axis='time', sr=SAMPLE_RATE, hop_length=HOP_LENGTH)
    plt.title(title)
    plt.colorbar(format='%+2.0f dB')
    plt.tight_layout()
    plt.show()

def main():
    args = parse_args()
    
    # Create output directory
    ensure_dir(args.output_dir)
    
    # Get all audio files
    keyword_files = glob.glob(os.path.join(args.input_dir, "start", "*.wav"))
    noise_files = glob.glob(os.path.join(args.input_dir, "noise", "*.wav"))
    
    print(f"Found {len(keyword_files)} keyword files and {len(noise_files)} noise files")
    
    # Extract features from keyword files
    keyword_features = []
    keyword_labels = []
    
    print("Extracting features from keyword files...")
    for file in tqdm(keyword_files):
        features = extract_features(file)
        keyword_features.append(features)
        keyword_labels.append(1)  # 1 for keyword
        
        if args.visualize and len(keyword_features) == 1:
            visualize_features(features, title=f"MFCC Features - Keyword")
    
    # Extract features from noise files
    noise_features = []
    noise_labels = []
    
    print("Extracting features from noise files...")
    for file in tqdm(noise_files):
        features = extract_features(file)
        noise_features.append(features)
        noise_labels.append(0)  # 0 for noise
        
        if args.visualize and len(noise_features) == 1:
            visualize_features(features, title=f"MFCC Features - Noise")
    
    # Combine features and labels
    all_features = keyword_features + noise_features
    all_labels = keyword_labels + noise_labels
    
    # Convert to numpy arrays
    features_array = np.array(all_features)
    labels_array = np.array(all_labels)
    
    # Save features and labels
    features_file = os.path.join(args.output_dir, "features.npy")
    labels_file = os.path.join(args.output_dir, "labels.npy")
    
    np.save(features_file, features_array)
    np.save(labels_file, labels_array)
    
    # Also save as pickle for compatibility
    dataset = {
        'features': features_array,
        'labels': labels_array
    }
    
    with open(os.path.join(args.output_dir, "dataset.pkl"), 'wb') as f:
        pickle.dump(dataset, f)
    
    print("\nFeature extraction complete!")
    print(f"Extracted features shape: {features_array.shape}")
    print(f"Labels shape: {labels_array.shape}")
    print(f"Saved features to {features_file}")
    print(f"Saved labels to {labels_file}")

if __name__ == "__main__":
    main()