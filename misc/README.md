# Misc Tools & Test Files# Miscellaneous Utilities



This directory contains utility scripts and standalone test modules.This directory contains experimental scripts and visualization tools.



## Audio Analysis Tool## Contents



**`analyze_audio_capture.py`** - Unified tool for processing Vivado ILA captures### `fft_visualize.py`

- Loads CSV exports from ILA

- Extracts audio samplesFFT visualization and testing utility for verifying FFT implementation.

- Generates WAV files

- Performs signal analysis (DC offset, clipping, frequency spectrum)**Usage:**

- Creates visualization plots```bash

python misc/fft_visualize.py

Usage:```

```bash

# Analyze ILA CSV and create WAVGenerates plots showing:

python analyze_audio_capture.py audio_capture.csv --wav output.wav- Time-domain waveforms

- Frequency-domain spectrum

# With plots- FFT magnitude response

python analyze_audio_capture.py audio_capture.csv --wav output.wav --plot

Useful for:

# From already-extracted hex file- Debugging FFT algorithms

python analyze_audio_capture.py samples.txt --format hex --wav output.wav- Verifying FFT output correctness

```- Understanding frequency characteristics of audio samples



## Test Modules## Notes



**`i2s_mic_test.v`** - Standalone I2S microphone test moduleThis directory is for experiments and quick scripts that don't fit into the main pipeline. Tools here may be rough/undocumented.

- Tests SPH0645 I2S MEMS microphone

- LED indicators for validationUse this folder for small experiments that don't belong in the main pipeline. Example content:

- Used during initial hardware bringup

- Not part of main KWS pipeline- `fft_visualize.py` — quick script to compute and plot FFTs of WAV files (included).

- Notes or small testbenches for Verilog experiments. Place waveform files or small sample inputs here when you're exploring RTL behavior with recorded audio.

## Visualization

To visualize your recordings with the provided script, copy WAV files into `misc/` or point the script at `data/processed/<class>/` files. For example:

**`fft_visualize.py`** - FFT visualization tool for audio files

- Loads WAV files```

- Computes FFT# Visualize a single processed file

- Generates frequency spectrum plotspython misc/fft_visualize.py data/processed/start/start_0001.wav

- Useful for debugging audio quality

# Or copy a file to misc/ for quick experiments

## Test Datacopy data/processed/start/start_0001.wav misc/

python misc/fft_visualize.py misc/start_0001.wav

`audio_capture.csv` - Sample ILA capture (if present, for testing)```


---

**Note:** This directory contains development/testing utilities. The main KWS application is in the parent directories.
