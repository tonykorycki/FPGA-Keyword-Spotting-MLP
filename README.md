# FPGA-based Keyword Spotting System

This project implements a real-time keyword spotting pipeline fully on FPGA hardware (e.g., Digilent Basys 3), using Verilog HDL for the logic and Python for offline data preparation, training, and quantization.

## Overview

The system is designed to detect the keyword "start" in real-time audio input. It processes audio through an I2S microphone, extracts features using an on-chip FFT implementation, and performs inference using a quantized MLP neural network.

## Repository Structure

```
fpga-kws/
├── fpga/                      # FPGA design files
│   ├── rtl/                   # Verilog HDL modules
│   │   ├── i2s_rx.v           # I2S audio receiver
│   │   ├── frame_buffer.v     # Audio frame buffer
│   │   ├── fft_core.v         # FFT implementation
│   │   ├── feature_extractor.v # Feature extraction
│   │   ├── inference.v        # Neural network inference
│   │   ├── output_control.v   # Output controller
│   │   └── top.v              # Top-level module
│   ├── tb/                    # Testbenches
│   ├── sim/                   # Simulation scripts
│   ├── constraints/           # FPGA pin constraints
│   └── project/               # Vivado project files
├── python/                    # Python scripts for model training
│   ├── collect_data.py        # Audio data collection
│   ├── make_features.py       # Feature extraction
│   ├── train_model.py         # Model training
│   ├── quantize_model.py      # Model quantization
│   └── generate_mem.py        # Memory file generation
└── docs/                      # Documentation
    ├── architecture.md        # System architecture overview
    ├── notes.md               # Development notes
    └── metrics.md             # Performance metrics
```

## Documentation

- **[INFERENCE.md](fpga/INFERENCE.md)** - Complete guide to the neural network inference module (architecture, testing, debugging)
- **[TODO.md](fpga/rtl/TODO.md)** - FPGA system architecture and module implementation guide
- **[architecture.md](docs/architecture.md)** - High-level system overview
- **[metrics.md](docs/metrics.md)** - Performance benchmarks

## Getting Started

### Prerequisites

- Digilent Basys 3 FPGA board (or similar)
- Xilinx Vivado Design Suite
- I2S MEMS microphone (e.g., SPH0645LM4H)
- Python 3.7+ with TensorFlow and librosa

### FPGA Implementation

The hardware implementation consists of several key components:

1. **I2S Audio Interface** - Receives digital audio from an I2S MEMS microphone
2. **Frame Buffer** - Collects and manages audio samples into frames with overlap
3. **FFT Core** - Computes the Fast Fourier Transform of audio frames
4. **Feature Extractor** - Extracts MFCC-like features from FFT outputs
5. **Inference Engine** - Runs a quantized MLP model to detect the keyword
6. **Output Controller** - Manages LED visualization and detection signals

### Model Training

The Python scripts provide a complete pipeline for:
1. Collecting audio samples
2. Extracting features
3. Training a neural network model
4. Quantizing the model for FPGA implementation
5. Generating memory initialization files for the FPGA

#### Running the Complete Pipeline

To run the entire model training pipeline with a single command, use `run_pipeline.py`:

```
python run_pipeline.py
```

This script will:
1. Convert your raw recordings to the standard format
2. Extract MFCC features from the audio files
3. Train the neural network model
4. Quantize the model for FPGA implementation

You can customize the pipeline with these options:
```
python run_pipeline.py --epochs 100 --batch_size 64 --hidden_size 128 --bits 16 --visualize
```

Available options:
- `--skip_convert`: Skip the audio conversion step (if already done)
- `--skip_features`: Skip the feature extraction step (if already done)
- `--epochs`: Number of training epochs (default: 50)
- `--batch_size`: Training batch size (default: 32) 
- `--hidden_size`: Size of the hidden layer (default: 64)
- `--bits`: Bit precision for quantization (default: 8)
- `--visualize`: Show visualizations during feature extraction

## Recording data

If you're collecting samples with Audacity (or a similar recorder) for the three conditions used by this project, follow these recommendations to keep your dataset consistent and easy to use:

- Recommended file format: 16 kHz sample rate, 16-bit PCM, mono WAV. This is the format our feature pipelines expect. Short clips (around 1 second) work well for a single-word keyword like "start". For background `silence` and `noise` samples, record the same duration as your keyword clips.
- Folder structure:
  - `data/preprocessed/` — Put your raw recordings here:
    - `data/preprocessed/start/` — recorded utterances of the keyword "start" (aim ~20 samples)
    - `data/preprocessed/silence/` — short background silence clips (no speech)
    - `data/preprocessed/noise/` — background noise clips (fan, room, street noise, etc.)
  - `data/processed/` — Standardized 16kHz, 16-bit PCM, mono WAV files (created by the batch conversion script)
- Naming scheme: use a predictable, zero-padded naming convention, e.g. `start_0001.wav`, `silence_0001.wav`, `noise_0001.wav`. This makes it easy to batch-process files.
- Audacity tips:
  - Set the project rate (bottom-left of the Audacity window) to 16000 Hz before recording.
  - Record in mono. If your microphone provides a stereo signal, export as mono (mix to mono) when saving.
  - When exporting: File → Export → Export as WAV and choose "Signed 16-bit PCM" as the encoding.
  - Keep peaks below -6 dB to avoid clipping; ensure consistent microphone distance and orientation between samples.
  - Use a pop filter or slight off-axis microphone placement to reduce plosives.
- Quantity & variation: for an initial dataset, ~20 good-quality examples per class is a reasonable starting point. Increase diversity (different speakers, positions, background conditions) for better generalization.
- Processing workflow:
  1. Record your samples using Audacity or another audio recorder
  2. Save your raw files into the appropriate `data/preprocessed/[class]/` folder 
  3. Run the batch conversion script to standardize all files:
     ```
     python python/batch_convert.py
     ```
  4. The standardized files will be created in `data/processed/[class]/` folders
  5. Proceed with feature extraction and model training using the processed files

The `python/` scripts (notably `make_features.py` and `train_model.py`) expect your audio dataset under `data/processed/` when producing features and training.## License

[License information]