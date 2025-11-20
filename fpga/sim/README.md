# Audio Pipeline Testbench - Quick Start Guide

## Running in Vivado Simulator

### Prerequisites
1. Vivado 2019.1 or later
2. FFT IP core (xfft_0) must be generated in your project
3. All RTL files added to project

### Setup Steps

#### Method 1: Using TCL Script (Recommended)
```tcl
# In Vivado TCL Console (from project root)
cd fpga/sim
source setup_pipeline_sim.tcl

# Launch simulation
launch_simulation

# Add waveforms (optional but helpful)
source add_waves.tcl

# Run simulation
run 500ms
# Or: run all
```

#### Method 2: Manual Setup
1. Open Vivado project: `fpga/project/fpga_kws_inference/fpga_kws_inference.xpr`
2. Add testbench to simulation sources:
   - Right-click **Simulation Sources**
   - **Add Sources** → **Add or create simulation sources**
   - Add: `fpga/tb/tb_audio_pipeline.v`
3. Set as top module:
   - Right-click `tb_audio_pipeline` in Sources
   - **Set as Top**
4. Run simulation:
   - **Flow Navigator** → **Simulation** → **Run Behavioral Simulation**
   - In TCL console: `run 500ms`

### What to Expect

The testbench runs **7 audio tests** sequentially:

1. **Silence** (all zeros)
2. **DC Offset** (constant value)
3. **440 Hz Sine** (musical A4 note)
4. **1 kHz Sine** (test tone)
5. **Dual Tone** (DTMF '1' digit: 697 Hz + 1209 Hz)
6. **Chirp** (frequency sweep 200 → 4000 Hz)
7. **White Noise** (random signal)

Each test:
- Generates ~2048 audio samples
- Produces 3-4 frames through the pipeline
- Shows features extracted for each frame

### Expected Console Output

```
==========================================
AUDIO PIPELINE TESTBENCH
==========================================
Mode: WITH FEATURE AVERAGER
==========================================

[100000] Reset released

========================================
TEST #1: Silence
========================================
[30965000] Frame #0 ready
[93705000] Features #0 ready (DC=0, Bin[10]=0, Bin[64]=0)
...
✓ Received 3 frames
Pipeline stats: Frames=3, Features=3, Averaged=3

========================================
TEST #2: DC Offset
========================================
...
```

### Interpreting Results

**Frame Buffer:**
- Should see `frame_ready` pulse every ~32ms (512 samples @ 16 kHz)
- `frames_received` counter increments

**FFT Core:**
- `fft_done` pulses after each frame
- Takes ~600 clock cycles per FFT

**Feature Extractor:**
- `features_valid` indicates feature extraction complete
- Check `features[0]` (DC), `features[10]` (low freq), etc.
- Values should be 0-31 (log2 of magnitude)

**Feature Averager (if enabled):**
- `averaged_valid` shows averaged output
- Accumulates over 4 frames in this test config

### Adjusting Test Parameters

In `tb_audio_pipeline.v`, modify:

```verilog
// Enable/disable feature averager
parameter ENABLE_AVERAGER = 1;  // 0 or 1

// Number of audio samples per test
parameter NUM_SAMPLES = 2048;   // Increase for longer tests

// Averager window size (in feature_averager instantiation)
.WINDOW_FRAMES(4)  // Change to 31 for full 1-second averaging
```

### Waveform Analysis

Add signals to waveform viewer:
```tcl
# Pipeline overview
add_wave /tb_audio_pipeline/*

# Detailed FFT internals
add_wave /tb_audio_pipeline/fft/state
add_wave /tb_audio_pipeline/fft/sample_counter

# Feature extraction
add_wave /tb_audio_pipeline/feat_ext/state
add_wave /tb_audio_pipeline/feat_ext/magnitude[0]
add_wave /tb_audio_pipeline/feat_ext/features[0]
```

### Troubleshooting

**FFT IP not found:**
- Generate FFT IP in Vivado: **IP Catalog** → search "FFT" → customize and generate
- Or use existing IP from `fpga/project/.../ip/xfft_0/`

**Simulation runs forever:**
- Check console output - tests complete in ~400ms simulated time
- Verify I2S clock generation is working

**No features extracted:**
- Check FFT output is valid
- Verify feature extractor receives `fft_done` signal
- Look for timing/handshake issues in waveform

**Averager not working:**
- Ensure `ENABLE_AVERAGER = 1`
- Check `feature_averager.v` is compiled
- Verify window size isn't too large for test

### Performance Notes

**Fast Simulation Mode (FAST_SIM = 1, default):**
- **Simulation time:** ~30 seconds real-time for all 7 tests
- **Simulated time:** ~30ms
- Bypasses I2S protocol, injects samples directly at 16 kHz
- Each test uses 600 samples (1 frame) for quick validation

**Real I2S Mode (FAST_SIM = 0):**
- **Simulation time:** ~10-20 minutes real-time
- **Simulated time:** ~400ms
- Simulates full I2S timing (BCLK, LRCLK, bit-by-bit transmission)
- Use this only when debugging I2S receiver issues

### Next Steps

After validating in simulation:
1. Test individual modules (I2S, frame buffer, etc.) separately if issues found
2. Use ILA for hardware testing with real microphone
3. Compare extracted features with Python `make_features.py` output
4. Integrate with inference engine for end-to-end testing
