#!/usr/bin/env python3
"""
Quick Audio Spectrum and Spectrogram Visualizer

Usage:
    python fft_visualize.py /path/to/file.wav

This will:
 - Plot and save the FFT magnitude spectrum (in dB)
 - Plot and save the spectrogram (log-scaled STFT)
"""

import sys
import os
import numpy as np
import matplotlib.pyplot as plt
import librosa
import librosa.display

def load_wav(path):
    """Load a WAV file as mono float32."""
    try:
        import soundfile as sf
        data, sr = sf.read(path)
        if data.ndim > 1:
            data = data.mean(axis=1)
        return data.astype(np.float32), sr
    except Exception:
        from scipy.io import wavfile
        sr, data = wavfile.read(path)
        if data.ndim > 1:
            data = data.mean(axis=1)
        if data.dtype.kind in 'iu':
            maxv = float(2 ** (8 * data.dtype.itemsize - 1))
            data = data.astype('float32') / maxv
        return data, sr

def compute_fft(data, sr):
    """Compute magnitude spectrum using FFT."""
    win = np.hanning(len(data))
    data = data * win
    fft = np.fft.rfft(data)
    mag = np.abs(fft)
    freqs = np.fft.rfftfreq(len(data), 1.0 / sr)
    return freqs, mag

def plot_spectrum(freqs, mag, sr, out_png):
    """Plot magnitude spectrum (in dB)."""
    plt.figure(figsize=(8, 4))
    plt.plot(freqs, 20 * np.log10(mag / np.max(mag) + 1e-10))
    plt.xlim(0, sr / 2)
    plt.ylim(-80, 0)
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Magnitude (dB)')
    plt.title('FFT Magnitude Spectrum')
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(out_png)
    print('Saved FFT spectrum →', out_png)
    plt.close()

def plot_spectrogram(data, sr, out_png):
    """Plot log-scaled spectrogram."""
    n_fft = 512
    hop = 256
    S = np.abs(librosa.stft(data, n_fft=n_fft, hop_length=hop))
    S_db = librosa.amplitude_to_db(S, ref=np.max)

    plt.figure(figsize=(8, 4))
    librosa.display.specshow(S_db, sr=sr, hop_length=hop, x_axis='time', y_axis='linear', cmap='magma')
    plt.colorbar(format='%+2.0f dB')
    plt.title('Spectrogram (Linear Frequency)')
    plt.tight_layout()
    plt.savefig(out_png)
    print('Saved spectrogram →', out_png)
    plt.close()

def main():
    if len(sys.argv) != 2:
        print('Usage: python fft_visualize.py file.wav')
        return

    path = sys.argv[1]
    data, sr = load_wav(path)

    # FFT spectrum
    freqs, mag = compute_fft(data, sr)
    fft_png = os.path.splitext(path)[0] + '_fft.png'
    plot_spectrum(freqs, mag, sr, fft_png)

    # Spectrogram
    spec_png = os.path.splitext(path)[0] + '_spec.png'
    plot_spectrogram(data, sr, spec_png)

if __name__ == '__main__':
    main()
