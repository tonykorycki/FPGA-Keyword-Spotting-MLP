#!/usr/bin/env python3
"""
Unified Audio Capture Analysis Tool
Handles Vivado ILA CSV exports, extracts samples, creates WAV, and analyzes quality
"""

import numpy as np
import matplotlib.pyplot as plt
import argparse
import sys
import wave
from pathlib import Path

class AudioCaptureAnalyzer:
    def __init__(self, sample_rate=16000):
        self.sample_rate = sample_rate
        self.samples = None
        
    def load_from_csv(self, csv_file):
        """Load samples from Vivado ILA CSV export"""
        print(f"Loading from CSV: {csv_file}")
        
        with open(csv_file, 'r') as f:
            lines = f.readlines()
        
        # Skip header rows, extract audio_sample column (usually column 3 or 4)
        samples = []
        for line in lines[2:]:  # Skip first 2 header rows
            parts = line.strip().split(',')
            if len(parts) >= 5:
                # Column 3 is i2s_receiver/audio_sample[15:0]
                sample_hex = parts[3].strip()
                if sample_hex and sample_hex not in ['0', '']:
                    try:
                        val = int(sample_hex, 16)
                        # Convert to signed 16-bit
                        if val > 32767:
                            val -= 65536
                        samples.append(val)
                    except ValueError:
                        continue
        
        self.samples = np.array(samples, dtype=np.int16)
        print(f"Loaded {len(self.samples)} samples")
        return self.samples
    
    def load_from_hex(self, hex_file):
        """Load samples from hex text file (one per line)"""
        print(f"Loading from hex file: {hex_file}")
        
        samples = []
        with open(hex_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    try:
                        line = line.replace('0x', '').replace('h', '')
                        val = int(line, 16)
                        # Convert to signed 16-bit
                        if val > 32767:
                            val -= 65536
                        samples.append(val)
                    except ValueError:
                        continue
        
        self.samples = np.array(samples, dtype=np.int16)
        print(f"Loaded {len(self.samples)} samples")
        return self.samples
    
    def save_wav(self, output_file):
        """Save samples as WAV file"""
        if self.samples is None:
            print("Error: No samples loaded!")
            return False
        
        # Convert signed samples back to unsigned for WAV
        unsigned_samples = np.array(self.samples, dtype=np.int16)
        
        with wave.open(output_file, 'w') as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(self.sample_rate)
            wav_file.writeframes(unsigned_samples.tobytes())
        
        duration = len(self.samples) / self.sample_rate
        print(f"\n✓ Created WAV file: {output_file}")
        print(f"  Samples: {len(self.samples)}")
        print(f"  Duration: {duration:.2f} seconds")
        print(f"  Sample rate: {self.sample_rate} Hz")
        return True
    
    def analyze(self):
        """Perform comprehensive audio analysis"""
        if self.samples is None:
            print("Error: No samples loaded!")
            return
        
        print("\n" + "="*60)
        print("AUDIO CAPTURE ANALYSIS REPORT")
        print("="*60)
        
        # Basic statistics
        print("\n=== Signal Statistics ===")
        print(f"Samples: {len(self.samples)}")
        print(f"Duration: {len(self.samples) / self.sample_rate:.3f} seconds")
        
        min_val = int(np.min(self.samples))
        max_val = int(np.max(self.samples))
        mean_val = int(np.mean(self.samples))
        
        # Convert to unsigned for hex display
        min_hex = min_val if min_val >= 0 else (min_val + 65536)
        max_hex = max_val if max_val >= 0 else (max_val + 65536)
        mean_hex = mean_val if mean_val >= 0 else (mean_val + 65536)
        
        print(f"Min value: {min_val:6d} (0x{min_hex:04X})")
        print(f"Max value: {max_val:6d} (0x{max_hex:04X})")
        print(f"Mean: {mean_val:6d} (0x{mean_hex:04X})")
        print(f"Range: {max_val - min_val:6d}")
        print(f"Std dev: {np.std(self.samples):6.1f}")
        
        # DC offset analysis
        print("\n=== DC Offset Analysis ===")
        dc_offset = np.mean(self.samples)
        dc_percent = abs(dc_offset) / 32768 * 100
        print(f"DC Offset: {dc_offset:.2f} ({dc_percent:.2f}% of max)")
        
        if abs(dc_offset) > 5000:
            print("⚠️  Large DC offset detected (normal for SPH0645)")
            print("   This will be removed by FFT/feature extraction")
        else:
            print("✓ DC offset is acceptable")
        
        # Signal level analysis
        print("\n=== Signal Level Analysis ===")
        rms = np.sqrt(np.mean(self.samples.astype(float)**2))
        db_fs = 20 * np.log10(rms / 32768) if rms > 0 else -120
        print(f"RMS Amplitude: {rms:.2f} ({db_fs:.2f} dBFS)")
        
        zero_samples = np.sum(self.samples == 0)
        print(f"Zero samples: {zero_samples} ({zero_samples/len(self.samples)*100:.2f}%)")
        
        # Peak detection
        peak_positive = np.max(self.samples)
        peak_negative = np.min(self.samples)
        dynamic_range = peak_positive - peak_negative
        print(f"Dynamic range: {dynamic_range} counts")
        
        # Clipping detection
        near_max = np.sum(self.samples > 32000)
        near_min = np.sum(self.samples < -32000)
        clipping_percent = (near_max + near_min) / len(self.samples) * 100
        
        if clipping_percent > 1:
            print(f"⚠️  Potential clipping: {clipping_percent:.2f}%")
        else:
            print(f"✓ No significant clipping ({clipping_percent:.3f}%)")
        
        # Frequency analysis
        print("\n=== Frequency Analysis ===")
        if len(self.samples) >= 256:
            # Use appropriate FFT size
            fft_size = min(len(self.samples), 8192)
            fft_result = np.fft.rfft(self.samples[:fft_size])
            magnitude = np.abs(fft_result)
            frequencies = np.fft.rfftfreq(fft_size, 1/self.sample_rate)
            
            # Find dominant frequencies (skip DC bin)
            top_bins = np.argsort(magnitude[1:])[-5:][::-1] + 1
            
            print(f"FFT Size: {fft_size} samples")
            print(f"Frequency resolution: {self.sample_rate/fft_size:.2f} Hz")
            print("\nDominant frequencies:")
            for i, bin_idx in enumerate(top_bins, 1):
                freq = frequencies[bin_idx]
                mag_db = 20 * np.log10(magnitude[bin_idx] / np.max(magnitude[1:]) + 1e-10)
                print(f"  {i}. {freq:6.1f} Hz at {mag_db:6.1f} dB")
        else:
            print("⚠️  Not enough samples for frequency analysis")
        
        # Summary
        print("\n" + "="*60)
        print("SUMMARY")
        print("="*60)
        
        issues = []
        if abs(dc_offset) > 20000:
            issues.append("Large DC offset (normal for SPH0645)")
        if clipping_percent > 5:
            issues.append("Significant clipping")
        if dynamic_range < 100:
            issues.append("Low dynamic range (too quiet?)")
        
        if issues:
            print("⚠️  Notes:")
            for issue in issues:
                print(f"   - {issue}")
        else:
            print("✓ Audio capture looks good!")
        
        print(f"\n✓ Analysis complete")
    
    def plot(self, output_file=None):
        """Generate visualization plots"""
        if self.samples is None:
            print("Error: No samples loaded!")
            return
        
        fig, axes = plt.subplots(3, 1, figsize=(12, 10))
        
        # Time domain
        time = np.arange(len(self.samples)) / self.sample_rate
        axes[0].plot(time, self.samples, linewidth=0.5)
        axes[0].set_xlabel('Time (s)')
        axes[0].set_ylabel('Amplitude')
        axes[0].set_title('Audio Waveform')
        axes[0].grid(True, alpha=0.3)
        
        # Zoomed view (first 1000 samples)
        zoom_samples = min(1000, len(self.samples))
        time_zoom = np.arange(zoom_samples) / self.sample_rate
        axes[1].plot(time_zoom, self.samples[:zoom_samples], linewidth=1)
        axes[1].set_xlabel('Time (s)')
        axes[1].set_ylabel('Amplitude')
        axes[1].set_title(f'Zoomed View (first {zoom_samples} samples)')
        axes[1].grid(True, alpha=0.3)
        
        # Frequency spectrum
        fft_size = min(len(self.samples), 8192)
        fft_result = np.fft.rfft(self.samples[:fft_size])
        magnitude = np.abs(fft_result)
        frequencies = np.fft.rfftfreq(fft_size, 1/self.sample_rate)
        
        # Convert to dB
        magnitude_db = 20 * np.log10(magnitude + 1e-10)
        
        axes[2].plot(frequencies, magnitude_db, linewidth=0.8)
        axes[2].set_xlabel('Frequency (Hz)')
        axes[2].set_ylabel('Magnitude (dB)')
        axes[2].set_title('Frequency Spectrum')
        axes[2].grid(True, alpha=0.3)
        axes[2].set_xlim([0, self.sample_rate/2])
        
        plt.tight_layout()
        
        if output_file:
            plt.savefig(output_file, dpi=150, bbox_inches='tight')
            print(f"\n✓ Saved plot: {output_file}")
        else:
            plt.show()
        
        plt.close()


def main():
    parser = argparse.ArgumentParser(
        description='Unified audio capture analysis tool for Vivado ILA exports',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Analyze Vivado ILA CSV export
  python analyze_audio_capture.py audio_capture.csv
  
  # Create WAV file
  python analyze_audio_capture.py audio_capture.csv --wav output.wav
  
  # Full analysis with plots
  python analyze_audio_capture.py audio_capture.csv --wav output.wav --plot
  
  # Analyze already-extracted hex file
  python analyze_audio_capture.py samples.txt --format hex --wav output.wav
        """
    )
    
    parser.add_argument('input_file', help='Input file (CSV or hex)')
    parser.add_argument('--format', choices=['csv', 'hex'], default='csv',
                       help='Input format (default: csv)')
    parser.add_argument('--wav', metavar='FILE', 
                       help='Output WAV file')
    parser.add_argument('--plot', metavar='FILE', nargs='?', const='plot.png',
                       help='Generate plot (optional: specify output file)')
    parser.add_argument('--sample-rate', type=int, default=16000,
                       help='Sample rate in Hz (default: 16000)')
    parser.add_argument('--no-analysis', action='store_true',
                       help='Skip detailed analysis')
    
    args = parser.parse_args()
    
    # Create analyzer
    analyzer = AudioCaptureAnalyzer(sample_rate=args.sample_rate)
    
    # Load samples
    try:
        if args.format == 'csv':
            analyzer.load_from_csv(args.input_file)
        else:
            analyzer.load_from_hex(args.input_file)
    except Exception as e:
        print(f"Error loading file: {e}")
        return 1
    
    if analyzer.samples is None or len(analyzer.samples) == 0:
        print("Error: No samples loaded!")
        return 1
    
    # Save WAV if requested
    if args.wav:
        analyzer.save_wav(args.wav)
    
    # Run analysis
    if not args.no_analysis:
        analyzer.analyze()
    
    # Generate plot if requested
    if args.plot:
        try:
            analyzer.plot(args.plot if args.plot != True else None)
        except Exception as e:
            print(f"Warning: Could not generate plot: {e}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
