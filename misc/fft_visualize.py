"""Quick FFT visualization for WAV files.

Usage:
    python fft_visualize.py /path/to/file.wav

This will plot the magnitude spectrum and save a PNG next to the WAV.
"""
import sys
import os
import numpy as np
import matplotlib.pyplot as plt

def load_wav(path):
    try:
        import soundfile as sf
        data, sr = sf.read(path)
        if data.ndim > 1:
            data = data.mean(axis=1)
        return data, sr
    except Exception:
        from scipy.io import wavfile
        sr, data = wavfile.read(path)
        if data.ndim > 1:
            data = data.mean(axis=1)
        # normalize if integer
        if data.dtype.kind in 'iu':
            maxv = float(2 ** (8 * data.dtype.itemsize - 1))
            data = data.astype('float32') / maxv
        return data, sr

def compute_fft(data, sr):
    # apply window and compute magnitude
    win = np.hanning(len(data))
    data = data * win
    fft = np.fft.rfft(data)
    mag = np.abs(fft)
    freqs = np.fft.rfftfreq(len(data), 1.0 / sr)
    return freqs, mag

def plot_spectrum(freqs, mag, out_png):
    plt.figure(figsize=(8,4))
    plt.plot(freqs, 20 * np.log10(mag + 1e-8))
    plt.xlim(0, 8000)
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Magnitude (dB)')
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(out_png)
    print('Saved', out_png)

def main():
    if len(sys.argv) != 2:
        print('Usage: python fft_visualize.py file.wav')
        return
    path = sys.argv[1]
    data, sr = load_wav(path)
    freqs, mag = compute_fft(data, sr)
    out_png = os.path.splitext(path)[0] + '_fft.png'
    plot_spectrum(freqs, mag, out_png)

if __name__ == '__main__':
    main()
