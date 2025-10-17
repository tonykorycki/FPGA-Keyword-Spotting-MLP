"""Small utility to resample and standardize WAV files to 16 kHz, 16-bit PCM, mono.

Usage:
    python resample_wav.py /path/to/input.wav /path/to/output.wav

This script uses `soundfile` and `resampy` if available, otherwise falls back to `scipy`.
"""
import sys
import os

TARGET_SR = 16000

def resample_and_write(in_path, out_path, target_sr=TARGET_SR):
    try:
        import soundfile as sf
        import resampy
    except Exception:
        # fallback
        from scipy.io import wavfile
        import numpy as np

        sr, data = wavfile.read(in_path)
        # convert to float
        if data.dtype != 'float32':
            data = data.astype('float32') / max(1, float(2 ** (8 * data.dtype.itemsize - 1)))
        # mono
        if data.ndim > 1:
            data = data.mean(axis=1)
        if sr != target_sr:
            import librosa
            data = librosa.resample(data, orig_sr=sr, target_sr=target_sr)
        # scale back to int16
        data_out = (data * 32767.0).clip(-32768, 32767).astype('int16')
        wavfile.write(out_path, target_sr, data_out)
        return

    data, sr = sf.read(in_path, always_2d=True)
    # mix to mono if needed
    if data.shape[1] > 1:
        data = data.mean(axis=1)
    else:
        data = data[:, 0]

    if sr != target_sr:
        data = resampy.resample(data, sr, target_sr)

    # write as 16-bit PCM
    sf.write(out_path, data, samplerate=target_sr, subtype='PCM_16')


def main():
    if len(sys.argv) != 3:
        print('Usage: python resample_wav.py input.wav output.wav')
        sys.exit(2)
    in_path = sys.argv[1]
    out_path = sys.argv[2]
    os.makedirs(os.path.dirname(out_path) or '.', exist_ok=True)
    resample_and_write(in_path, out_path)
    print(f'Wrote standardized WAV to {out_path}')


if __name__ == '__main__':
    main()
