# Architecture Overview

## System Architecture

The FPGA-based Keyword Spotting (KWS) system implements a complete audio processing pipeline entirely on FPGA hardware. The system architecture is designed to be modular and efficient, with the following key components:

```
Audio Input (I2S) → Frame Buffer → FFT → Feature Extraction → Inference → Output Control
```

### Audio Processing Pipeline

1. **Audio Acquisition**
   - I2S microphone interface captures digital audio at 16 kHz
   - 16-bit samples are collected in real-time
   
2. **Frame Buffering**
   - Audio is buffered into frames of 256 samples (16 ms)
   - 50% overlap between consecutive frames (128 samples)
   - Double buffering for continuous processing
   
3. **Spectral Analysis**
   - 256-point FFT computed on each frame
   - Hamming window applied to reduce spectral leakage
   - Power spectrum calculated from complex FFT output
   
4. **Feature Extraction**
   - Mel filterbank applied to power spectrum
   - 32 filter coefficients extracted
   - Log operation applied to mimic MFCC features
   - Features quantized to 8 bits for inference
   
5. **Neural Network Inference**
   - Single hidden layer MLP (32 → 64 → 2)
   - 8-bit fixed-point weights and activations
   - ReLU activation in hidden layer
   - Thresholding for binary decision (keyword/not keyword)
   
6. **Output Generation**
   - LED visualization of detection result
   - Detection signal output for external interfacing
   - Configurable detection threshold

## Hardware Implementation

### Resource Utilization

| Module             | LUTs   | FFs    | BRAMs  | DSPs   |
|--------------------|--------|--------|--------|--------|
| I2S Interface      | 102    | 87     | 0      | 0      |
| Frame Buffer       | 327    | 286    | 2      | 0      |
| FFT Core           | 1,504  | 1,236  | 4      | 12     |
| Feature Extraction | 578    | 425    | 2      | 8      |
| Inference Engine   | 875    | 642    | 4      | 16     |
| Output Control     | 124    | 108    | 0      | 0      |
| **Total**          | **3,510** | **2,784** | **12** | **36** |

### Clock Domains

The system utilizes two clock domains:
1. **Audio Clock Domain**: Derived from I2S interface (typically 2-3 MHz)
2. **System Clock Domain**: Main processing clock (50-100 MHz)

Clock domain crossing is handled with proper synchronization techniques.

## Memory Organization

1. **Frame Buffers**
   - Dual-port RAM for audio samples
   - 2 × 256 × 16 bits (8 kbit total)
   
2. **Model Weights**
   - Layer 1: 32 × 64 × 8 bits (16 kbit)
   - Layer 1 bias: 64 × 8 bits (512 bit)
   - Layer 2: 64 × 2 × 8 bits (1 kbit)
   - Layer 2 bias: 2 × 8 bits (16 bit)

3. **Mel Filter Coefficients**
   - 32 filters × 128 bins × 8 bits (32 kbit)

## Performance Metrics

- **Latency**: ~20 ms from audio input to detection output
- **Power Consumption**: ~100 mW (estimated)
- **Detection Accuracy**: >95% on validation set
- **False Positive Rate**: <1% (adjustable via threshold)