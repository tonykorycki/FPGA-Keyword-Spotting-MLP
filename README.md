# FPGA-based Keyword Spotting System

Real-time keyword spotting system targeting Digilent Basys 3 FPGA. Combines Python-trained quantized neural network with Verilog hardware implementation for edge AI audio processing.

## Project Status

**Completed:**
- Python ML pipeline: data collection, feature extraction, model training
- INT8 quantized 3-layer MLP (257→32→16→2) with 98% test accuracy
- Verilog inference engine with 99% simulation accuracy (797/800 test cases)
- Successful Vivado synthesis on Basys 3 (16.84% LUTs, 6.46% FFs)

**In Progress:**
- Audio preprocessing pipeline (I2S receiver, FFT, feature extraction)
- System integration and top-level module

## Overview

The system detects the keyword "start" in real-time audio using a hardware neural network running on INT8 quantized weights.

## Repository Structure

```
fpga-kws/
├── data/                       # Audio dataset
│   ├── raw/                    # Raw audio recordings
│   │   ├── noise/              # Background noise samples
│   │   ├── silence/            # Silence samples
│   │   ├── similar/            # Similar-sounding words
│   │   ├── speech/             # General speech samples
│   │   ├── start/              # "start" keyword samples
│   │   └── words/              # Other words
│   └── processed/              # Extracted features (.npy files)
│       ├── features.npy        # MFCC feature vectors
│       ├── labels.npy          # Binary labels (0/1)
│       └── ...
├── fpga/                       # FPGA design files
│   ├── rtl/                    # Verilog source modules
│   │   ├── inference.v         # Neural network inference engine (COMPLETE)
│   │   ├── i2s_rx.v            # I2S audio receiver (TODO)
│   │   ├── frame_buffer.v      # Audio windowing (TODO)
│   │   ├── fft_core.v          # 512-point FFT (TODO)
│   │   ├── feature_extractor.v # Mel-spectrogram (TODO)
│   │   ├── output_control.v    # Output control (TODO)
│   │   └── top.v               # System integration (TODO)
│   ├── tb/                     # Testbenches
│   │   ├── tb_inference.v      # Inference engine testbench
│   │   ├── tb_i2s_rx.v
│   │   ├── tb_frame_buffer.v
│   │   └── ...
│   ├── sim/                    # Simulation scripts
│   ├── constraints/            # Pin constraints (XDC)
│   │   └── basys3.xdc          # Basys 3 board constraints
│   ├── project/                # Vivado project
│   │   └── fpga_kws_inference/ # Vivado project files (.xpr)
│   └── INFERENCE.md            # Inference module guide
├── models/                     # Trained models and weights
│   ├── kws_model.h5            # Keras float32 model
│   ├── quantized_weights.npz   # INT8 quantized weights
│   ├── scales.json             # Quantization scale factors
│   ├── test_input.npy          # Test vectors (float)
│   ├── test_input_hex.txt      # Test vectors (INT8 hex)
│   ├── test_output_ref.txt     # Expected predictions
│   └── mem/                    # FPGA memory init files
│       ├── layer0_weights.mem  # Layer 0 weights (8224 bytes)
│       ├── layer0_bias.mem     # Layer 0 biases (32 values)
│       ├── layer1_weights.mem  # Layer 1 weights (512 bytes)
│       ├── layer1_bias.mem     # Layer 1 biases (16 values)
│       ├── layer2_weights.mem  # Layer 2 weights (32 bytes)
│       └── layer2_bias.mem     # Layer 2 biases (2 values)
├── python/                     # Python ML pipeline
│   ├── collect_data.py         # Audio data collection
│   ├── make_features.py        # Feature extraction (MFCC)
│   ├── train_model.py          # Model training
│   ├── quantize_model.py       # INT8 quantization
│   ├── convert_test_vectors.py # Generate test vectors
│   ├── simulate_quantized_inference.py  # Python inference check
│   ├── compare_models.py       # Float vs quantized comparison
│   └── utils/
│       └── plotting.py         # Visualization utilities
├── misc/                       # Experiments and utilities
│   ├── fft_visualize.py        # FFT visualization
│   └── README.md
└── docs/                       # Documentation
    ├── project_status.md       # 📍 Current status & roadmap
    ├── architecture.md         # System architecture
    ├── metrics.md              # Performance metrics
    └── notes.md                # Development notes
```

## Documentation

- **[project_status.md](docs/project_status.md)** - Current status and roadmap
- **[INFERENCE.md](fpga/INFERENCE.md)** - Inference module guide (architecture, testing, synthesis)
- **[audio_pipeline.md](docs/audio_pipeline.md)** - Audio preprocessing module specifications
- **[architecture.md](docs/architecture.md)** - System design overview
- **[metrics.md](docs/metrics.md)** - Performance benchmarks

## Quick Start

### 1. Python Model Training

Train the keyword spotting model and generate quantized weights:

```bash
# Install dependencies
pip install -r requirements.txt

# Extract features from audio data
python python/make_features.py

# Train the neural network
python python/train_model.py

# Quantize to INT8 and generate memory files
python python/quantize_model.py
```

This creates:
- `models/kws_model.h5` - Float32 Keras model
- `models/quantized_weights.npz` - INT8 weights
- `models/mem/*.mem` - Verilog memory initialization files

### 2. FPGA Inference Engine (Current Status)

The inference module is **complete and verified**:

```bash
# Run Icarus Verilog simulation
cd fpga/tb
./run_inference_sim.sh   # Linux/WSL
# or
./run_inference_sim.ps1  # Windows PowerShell

# Expected output: 99% accuracy (797/800 correct)
```

**Vivado Synthesis Results:**
- Target: Basys 3 (xc7a35tcpg236-1)
- LUT usage: 16.84% (3,502 / 20,800)
- FF usage: 6.46% (2,686 / 41,600)
- Status: Successful, excellent resource headroom

### 3. Next Steps: Audio Pipeline (TODO)

The audio preprocessing pipeline is planned but not yet implemented:

**Modules to build:**
1. `i2s_rx.v` - I2S receiver for MEMS microphone
2. `frame_buffer.v` - 32ms audio windowing (512 samples @ 16kHz)
3. `fft_core.v` - 512-point FFT
4. `feature_extractor.v` - Log-mel spectrogram → 257 features
5. `top.v` - System integration

See [audio_pipeline.md](docs/audio_pipeline.md) for detailed specifications.

## Hardware Requirements

**Current (Inference Only):**
- Xilinx Vivado 2025.1 (or compatible)
- Digilent Basys 3 FPGA board (or equivalent Artix-7)

**Future (Full System):**
- I2S MEMS microphone (ICS-43434 or similar)
- 100 MHz clock source (available on Basys 3)

## Software Requirements

```
Python 3.8+
numpy
tensorflow
librosa
matplotlib
scikit-learn
```

Install via: `pip install -r requirements.txt`

## Model Architecture

**Neural Network:**
- Layer 0: 257 inputs → 32 outputs (Dense + ReLU)
- Layer 1: 32 inputs → 16 outputs (Dense + ReLU)  
- Layer 2: 16 inputs → 2 outputs (Dense, logits)
- Output: argmax(logits) → binary prediction

**Quantization:**
- Weights: INT8 (-127 to 127)
- Biases: INT32
- Activations: INT8 with ReLU clipping
- Accumulator: INT32 with requantization

**Accuracy:**
- Float32 model: ~98% on test set
- INT8 quantized: ~98% on test set
- Verilog simulation: 99% (797/800 test cases)

## Project Timeline

- Phase 1: Python ML pipeline and model training (COMPLETE)
- Phase 2: Quantization and memory file generation (COMPLETE)
- Phase 3: Verilog inference engine and verification (COMPLETE)
- Phase 4: Vivado synthesis and resource analysis (COMPLETE)
- Phase 5: Audio preprocessing pipeline (IN PROGRESS)
- Phase 6: System integration and hardware testing (PLANNED)

## License

MIT License - See LICENSE file for details

## Author

Tony Korycki
October 2025

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