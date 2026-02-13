#!/usr/bin/env python3
"""
Convert ILA captured audio data to WAV file
Reads CSV exported from Vivado ILA and creates a playable WAV file

Usage:
    python ila_to_wav.py captured_audio.csv output.wav
"""

import csv
import struct
import wave
import sys
import re

def parse_verilog_value(value_str):
    """Parse Verilog hex/binary values from ILA CSV"""
    value_str = value_str.strip()
    
    # Handle hex format: 0xABCD or h1234
    if value_str.startswith('0x') or value_str.startswith('0X'):
        return int(value_str, 16)
    elif value_str.startswith('h') or value_str.startswith('H'):
        return int(value_str[1:], 16)
    
    # Handle binary format: 0b1010 or b1010
    elif value_str.startswith('0b') or value_str.startswith('0B'):
        return int(value_str, 2)
    elif value_str.startswith('b') or value_str.startswith('B'):
        return int(value_str[1:], 2)
    
    # Handle decimal
    else:
        return int(value_str)

def twos_complement_to_signed(value, bits=16):
    """Convert unsigned int to signed int using two's complement"""
    if value >= (1 << (bits - 1)):
        return value - (1 << bits)
    return value

def csv_to_wav(csv_file, wav_file, sample_rate=16000):
    """
    Convert ILA CSV to WAV file
    
    Args:
        csv_file: Path to CSV exported from Vivado ILA
        wav_file: Output WAV file path
        sample_rate: Audio sample rate (default 16kHz for SPH0645)
    """
    
    print(f"Reading ILA data from: {csv_file}")
    
    # Read CSV and extract audio samples
    audio_samples = []
    
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        
        # Find the column name for audio_sample (may have module prefix)
        headers = reader.fieldnames
        audio_col = None
        valid_col = None
        
        for header in headers:
            if 'audio_sample' in header.lower():
                audio_col = header
            if 'sample_valid' in header.lower():
                valid_col = header
        
        if not audio_col:
            print("ERROR: Could not find 'audio_sample' column in CSV")
            print(f"Available columns: {headers}")
            return
        
        print(f"Using column: {audio_col}")
        if valid_col:
            print(f"Filtering by: {valid_col}")
        
        # Read samples
        for row in reader:
            # Only include samples where valid=1 (if column exists)
            if valid_col:
                try:
                    valid = parse_verilog_value(row[valid_col])
                    if valid != 1:
                        continue
                except:
                    pass
            
            # Parse audio sample value
            try:
                sample_value = parse_verilog_value(row[audio_col])
                # Convert to signed 16-bit
                signed_sample = twos_complement_to_signed(sample_value, 16)
                audio_samples.append(signed_sample)
            except Exception as e:
                print(f"Warning: Could not parse sample: {row[audio_col]} - {e}")
                continue
    
    if len(audio_samples) == 0:
        print("ERROR: No valid audio samples found in CSV")
        return
    
    print(f"Found {len(audio_samples)} audio samples")
    print(f"Duration: {len(audio_samples)/sample_rate:.3f} seconds")
    
    # Create WAV file
    print(f"Writing WAV file: {wav_file}")
    
    with wave.open(wav_file, 'w') as wav:
        # WAV parameters
        n_channels = 1      # Mono
        sampwidth = 2       # 16-bit
        framerate = sample_rate
        n_frames = len(audio_samples)
        
        wav.setparams((n_channels, sampwidth, framerate, n_frames, 'NONE', 'not compressed'))
        
        # Write audio data
        for sample in audio_samples:
            # Pack as signed 16-bit little-endian
            wav.writeframes(struct.pack('<h', sample))
    
    print(f"✓ WAV file created successfully!")
    print(f"  Format: 16-bit signed PCM, {sample_rate}Hz, Mono")
    print(f"  Duration: {len(audio_samples)/sample_rate:.3f}s")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ila_to_wav.py <input.csv> [output.wav] [sample_rate]")
        print()
        print("Example:")
        print("  python ila_to_wav.py captured_audio.csv output.wav")
        print("  python ila_to_wav.py captured_audio.csv output.wav 16000")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    wav_file = sys.argv[2] if len(sys.argv) > 2 else "output.wav"
    sample_rate = int(sys.argv[3]) if len(sys.argv) > 3 else 16000
    
    csv_to_wav(csv_file, wav_file, sample_rate)
