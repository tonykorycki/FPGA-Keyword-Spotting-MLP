#!/usr/bin/env python3
"""
Keyword Spotting System - FPGA-Compatible Feature Extraction
Author: Tony Korycki
Date: October 18, 2025

Extracts log FFT magnitude features from audio samples in data/raw/<label>/
and saves dataset arrays for FPGA-MLP training. When --visualize is used,
it shows both per-sample and averaged spectrograms for all classes.
"""

import os
import glob
import argparse
import numpy as np
from scipy.io import wavfile
import matplotlib.pyplot as plt
from tqdm import tqdm

# --- Configuration ---
SAMPLE_RATE = 16000
FRAME_SIZE = 512
HOP_SIZE = 256
TARGET_LEN = SAMPLE_RATE  # 1 second
USE_LOG_SCALE = True

# --- Helper Functions ---
def parse_args():
    parser = argparse.ArgumentParser(description="Extract FPGA-compatible FFT features from audio samples")
    parser.add_argument("--input_dir", type=str, default="data/raw",
                        help="Input directory containing label subfolders")
    parser.add_argument("--output_dir", type=str, default="data/processed",
                        help="Output directory for features and labels")
    parser.add_argument("--visualize", action="store_true",
                        help="Visualize sample + average spectrograms for each class")
    return parser.parse_args()


def ensure_dir(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)


def extract_fft_features(audio_file):
    """Compute log FFT magnitude features for one recording."""
    fs, data = wavfile.read(audio_file)
    if data.ndim > 1:
        data = data[:, 0]

    data = data.astype(np.float32)
    data = data / (np.max(np.abs(data)) + 1e-9)

    if len(data) < TARGET_LEN:
        data = np.pad(data, (0, TARGET_LEN - len(data)))
    else:
        data = data[:TARGET_LEN]

    frames = []
    for start in range(0, len(data) - FRAME_SIZE, HOP_SIZE):
        frame = data[start:start + FRAME_SIZE] * np.hamming(FRAME_SIZE)
        fft_mag = np.abs(np.fft.rfft(frame))
        if USE_LOG_SCALE:
            fft_mag = np.log1p(fft_mag)
        frames.append(fft_mag)
    return np.array(frames, dtype=np.float32)


def visualize_spectrograms(label_map, input_dir):
    """Show sample + average spectrogram per class (time–frequency plots)."""
    n_classes = len(label_map)
    total_plots = n_classes * 2

    # Compute dynamic grid size
    n_cols = 4  # one column for "sample", one for "average"
    n_rows = int(n_classes / 2)
    plt.figure(figsize=(10 * n_cols / 2, 3 * n_rows))

    plot_idx = 1

    for label_name in label_map.keys():
        folder = os.path.join(input_dir, label_name)
        wav_files = glob.glob(os.path.join(folder, "*.wav"))
        if not wav_files:
            print(f"Skipping '{label_name}' (no .wav files found)")
            continue

        # --- 1️⃣ Single-sample spectrogram (time vs freq) ---
        first_file = wav_files[0]
        fft_frames = extract_fft_features(first_file)
        plt.subplot(n_rows, n_cols, plot_idx)
        plt.imshow(fft_frames.T, aspect="auto", origin="lower",
                   cmap="magma", interpolation="nearest")
        plt.title(f"{label_name} - single sample")
        plt.ylabel("Frequency bins")
        plt.xlabel("Time frames (~16 ms each)")
        plot_idx += 1

        # --- 2️⃣ Average spectrogram across all files ---
        max_frames = max([extract_fft_features(f).shape[0] for f in wav_files])
        acc = np.zeros((max_frames, fft_frames.shape[1]), dtype=np.float32)
        count = np.zeros(max_frames, dtype=np.int32)

        for f in wav_files:
            spec = extract_fft_features(f)
            length = spec.shape[0]
            acc[:length] += spec
            count[:length] += 1

        count[count == 0] = 1
        avg_spec = acc / count[:, None]

        plt.subplot(n_rows, n_cols, plot_idx)
        plt.imshow(avg_spec.T, aspect="auto", origin="lower",
                   cmap="magma", interpolation="nearest")
        plt.title(f"{label_name} - average")
        plt.ylabel("Frequency bins")
        plt.xlabel("Time frames (~16 ms each)")
        plot_idx += 1

    plt.tight_layout()
    plt.show()


# --- Main ---
def main():
    args = parse_args()
    ensure_dir(args.output_dir)

    label_names = sorted([d for d in os.listdir(args.input_dir)
                          if os.path.isdir(os.path.join(args.input_dir, d))])
    # Map original folder names to "actual" label indices
    label_types = np.array(label_names, dtype=np.str_)
    actual_label_to_idx = {name: i for i, name in enumerate(label_names)}
    
    # Binary labeling: "start" = 1, everything else = 0
    label_map = {name: 1 if name == "start" else 0 for name in label_names}
    print(f"Found label folders with binary mapping: {label_map}")

    all_features, all_labels = [], []
    all_actual_labels = [] 
    visualize_data = []
    filenames = []

    for label_name, label_value in label_map.items():
        folder = os.path.join(args.input_dir, label_name)
        wav_files = glob.glob(os.path.join(folder, "*.wav"))
        if not wav_files:
            print(f"No files found in {folder}")
            continue

        print(f"Processing {len(wav_files)} files for label '{label_name}' ({label_value})")
        all_class_spectra = []

        for i, wav_path in enumerate(tqdm(wav_files, desc=f"Extracting {label_name}")):
            fft_frames = extract_fft_features(wav_path)
            feature_vec = fft_frames.mean(axis=0)
            all_features.append(feature_vec)
            all_labels.append(label_value)
            filenames.append(f"{label_name}/{os.path.basename(wav_path)}")


            # Save the actual label index (folder-based)
            all_actual_labels.append(actual_label_to_idx[label_name])
            all_class_spectra.append(fft_frames)

            if i == 0:
                example_fft = fft_frames  # save one example per class

        # Store visualization data
        if args.visualize:
            avg_fft = np.vstack(all_class_spectra).mean(axis=0)
            visualize_data.append((label_name, example_fft, avg_fft))

    # Save data
    features = np.array(all_features, dtype=np.float32)
    labels = np.array(all_labels, dtype=np.int32)
    labels_actual = np.array(all_actual_labels, dtype=np.int32)
    np.save(os.path.join(args.output_dir, "features.npy"), features)
    np.save(os.path.join(args.output_dir, "labels.npy"), labels)
    # New: per-sample actual labels and their names
    np.save(os.path.join(args.output_dir, "labels_actual.npy"), labels_actual)
    np.save(os.path.join(args.output_dir, "label_types.npy"), label_types)
    np.save(os.path.join(args.output_dir, "filenames.npy"), np.array(filenames))


    print("\nExtraction complete!")
    print(f"Feature shape: {features.shape}, Labels shape: {labels.shape}")
    print(f"Also saved labels_actual ({labels_actual.shape}) and label_types ({label_types.shape})")
    print(f"Binary label mapping: {label_map} (start=1, others=0)")
    
    # Count the number of samples in each class
    unique_labels, counts = np.unique(labels, return_counts=True)
    class_counts = dict(zip(unique_labels, counts))
    print(f"Class distribution (binary): {class_counts}")
    # Actual label distribution
    u_act, c_act = np.unique(labels_actual, return_counts=True)
    act_dist = {label_types[i]: int(c) for i, c in zip(u_act, c_act)}
    print(f"Class distribution (actual): {act_dist}")
    
    print(f"Saved to: {args.output_dir}")

    # --- Visualization section ---
    if args.visualize and visualize_data:
        visualize_spectrograms(label_map, args.input_dir)


if __name__ == "__main__":
    main()
