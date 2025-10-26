#!/usr/bin/env python3
"""
Keyword Spotting System - Audio Data Collection Script
Author: 
Date: October 17, 2025

This script records audio samples for training the keyword spotting system.
It prompts the user to speak the target keyword and background noise,
and saves the recordings as WAV files.
"""

import os
import sys
import time
import wave
import argparse
import numpy as np
import pyaudio
import matplotlib.pyplot as plt
from utils.plotting import visualize_audio

# Constants
SAMPLE_RATE = 16000
CHANNELS = 1
SAMPLE_WIDTH = 2  # 16-bit
RECORD_SECONDS = 1
KEYWORD = "start"

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Collect audio samples for KWS training")
    parser.add_argument("--output_dir", type=str, default="../data/raw",
                       help="Directory to save recorded audio files")
    parser.add_argument("--num_samples", type=int, default=50,
                       help="Number of samples to collect for each category")
    parser.add_argument("--visualize", action="store_true",
                       help="Visualize the recorded waveform")
    return parser.parse_args()

def ensure_dir(directory):
    """Create directory if it doesn't exist."""
    if not os.path.exists(directory):
        os.makedirs(directory)

def record_audio(seconds, sample_rate=SAMPLE_RATE, channels=CHANNELS):
    """Record audio from microphone."""
    p = pyaudio.PyAudio()
    
    stream = p.open(format=p.get_format_from_width(SAMPLE_WIDTH),
                    channels=channels,
                    rate=sample_rate,
                    input=True,
                    frames_per_buffer=1024)
    
    print("* Recording...")
    frames = []
    
    for i in range(0, int(sample_rate / 1024 * seconds)):
        data = stream.read(1024)
        frames.append(data)
    
    print("* Done recording")
    
    stream.stop_stream()
    stream.close()
    p.terminate()
    
    return b''.join(frames)

def save_wav(filename, audio_data, sample_rate=SAMPLE_RATE, channels=CHANNELS):
    """Save audio data as WAV file."""
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(sample_rate)
        wf.writeframes(audio_data)



def main():
    args = parse_args()
    
    # Create directories
    keyword_dir = os.path.join(args.output_dir, KEYWORD)
    noise_dir = os.path.join(args.output_dir, "noise")
    ensure_dir(keyword_dir)
    ensure_dir(noise_dir)
    
    # Collect keyword samples
    print(f"\nCollecting {args.num_samples} samples of the keyword '{KEYWORD}'")
    print("Press Enter when ready to record each sample")
    
    for i in range(args.num_samples):
        input(f"\nSample {i+1}/{args.num_samples} - Press Enter and say '{KEYWORD}'...")
        audio_data = record_audio(RECORD_SECONDS)
        filename = os.path.join(keyword_dir, f"{KEYWORD}_{i:03d}.wav")
        save_wav(filename, audio_data)
        print(f"Saved to {filename}")
        
        if args.visualize:
            visualize_audio(audio_data)
    
    # Collect background noise samples
    print(f"\nCollecting {args.num_samples} samples of background noise")
    print("Press Enter when ready to record each sample")
    
    for i in range(args.num_samples):
        input(f"\nSample {i+1}/{args.num_samples} - Press Enter and record background noise...")
        audio_data = record_audio(RECORD_SECONDS)
        filename = os.path.join(noise_dir, f"noise_{i:03d}.wav")
        save_wav(filename, audio_data)
        print(f"Saved to {filename}")
        
        if args.visualize:
            visualize_audio(audio_data)
    
    print("\nData collection complete!")
    print(f"Collected {args.num_samples} samples of '{KEYWORD}' in {keyword_dir}")
    print(f"Collected {args.num_samples} samples of background noise in {noise_dir}")

if __name__ == "__main__":
    main()