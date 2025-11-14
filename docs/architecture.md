# Architecture Overview

## System Architecture

The FPGA-based Keyword Spotting (KWS) system implements a complete audio processing pipeline on FPGA hardware.

**Pipeline**: Audio Input (I2S) → Frame Buffer → FFT → Feature Extraction → Inference → Output

### Current Status

**Completed:**
- Neural network inference engine (Verilog)
- Python training and quantization pipeline
- INT8 quantized 3-layer MLP model
- Test vector generation and verification

**In Progress:**
- Audio preprocessing modules (I2S, FFT, feature extraction)
- System integration
- Hardware testing on Basys 3

## Audio Processing Pipeline (Planned)

1. **Audio Acquisition** (i2s_rx.v - TODO)
   - I2S MEMS microphone interface
   - 16 kHz sample rate, 16-bit samples
   
2. **Frame Buffering** (frame_buffer.v - TODO)
   - Windowing into 32ms frames (512 samples @ 16kHz)
   - 50% overlap between consecutive frames
   
3. **Spectral Analysis** (fft_core.v - TODO)
   - 512-point FFT
   - Complex → magnitude conversion
   
4. **Feature Extraction** (feature_extractor.v - TODO)
   - Log-mel spectrogram computation
   - 257 feature coefficients extracted
   - INT8 quantization for inference
   
5. **Neural Network Inference** (inference.v - COMPLETE)
   - 3-layer MLP: 257 → 32 → 16 → 2
   - INT8 weights, INT32 biases
   - ReLU activation on hidden layers
   
6. **Output Control** (output_control.v - TODO)
   - LED visualization
   - Detection flag output

## Neural Network Architecture

### Layer Configuration

| Layer    | Input | Output | Weights      | Activation | Quantization |
|----------|-------|--------|--------------|------------|--------------|
| Layer 0  | 257   | 32     | 257×32=8,224 | ReLU       | INT8         |
| Layer 1  | 32    | 16     | 32×16=512    | ReLU       | INT8         |
| Layer 2  | 16    | 2      | 16×2=32      | None       | INT8         |
| **Total** |      |        | **8,768 weights** |        |              |

### Quantization Scheme

- **Weights:** INT8 (-127 to 127), stored in block RAM
- **Biases:** INT32, full precision
- **Activations:** INT8 after ReLU clipping
- **Accumulator:** INT32 for intermediate sums
- **Requantization:** Scale factors applied post-accumulation to prevent overflow

### Inference Dataflow

```
Input [257×INT8] → Layer 0 MAC → Requantize → ReLU → [32×INT8]
                                                          ↓
                         Layer 2 MAC → Requantize → [2×INT8] logits
                              ↑
                [16×INT8] ← ReLU ← Requantize ← MAC ← Layer 1
```

### MAC (Multiply-Accumulate) Operation

Sequential processing, one operation per cycle:
1. Load weight[i] and activation[i]
2. Multiply: product = weight × activation (16-bit result)
3. Accumulate: sum += product (32-bit accumulator)
4. Repeat for all inputs
5. Add bias
6. Requantize to INT8
7. Apply ReLU (if hidden layer)

## Hardware Implementation

### Current Resource Utilization (Inference Only)

Based on Vivado synthesis for Basys 3 (xc7a35tcpg236-1):

| Resource      | Used  | Available | Utilization |
|---------------|-------|-----------|-------------|
| LUTs          | 3,502 | 20,800    | 16.84%      |
| Flip-Flops    | 2,686 | 41,600    | 6.46%       |
| F7 Muxes      | 1,094 | 16,300    | 6.71%       |
| F8 Muxes      | 526   | 8,150     | 6.45%       |
| BRAMs         | 0     | 50        | 0%*         |
| DSPs          | 0     | 90        | 0%**        |

*Weights stored in distributed RAM (FFs) due to async reset  
**MAC implemented in fabric logic

**Resource Headroom:** 80%+ resources available for audio pipeline
**Resource Headroom:** 80%+ resources available for audio pipeline

### Timing Analysis

**Inference Latency (per sample):**
- Layer 0: 257 MAC cycles + 1 requantize = 258 cycles
- Layer 1: 32 MAC cycles + 1 requantize = 33 cycles  
- Layer 2: 16 MAC cycles + 1 requantize = 17 cycles
- Argmax: 1 cycle
- **Total: ~309 cycles @ 100 MHz = 3.09 μs per inference**

**Throughput:**
- System clock: 100 MHz (Basys 3 onboard oscillator)
- Inference rate: ~324k inferences/second
- Audio frame rate: ~31 Hz (32ms frames) → 0.03k frames/second
- **Headroom: 10,000× faster than required**

### Planned Full System Utilization

Estimated resource usage with audio pipeline:

| Module              | LUTs (est.) | FFs (est.) | BRAMs | DSPs |
|---------------------|-------------|------------|-------|------|
| Inference (actual)  | 3,502       | 2,686      | 0     | 0    |
| I2S Receiver        | ~100        | ~50        | 0     | 0    |
| Frame Buffer        | ~200        | ~512       | 2     | 0    |
| FFT Core            | ~2,000      | ~1,000     | 4     | 4    |
| Feature Extractor   | ~500        | ~300       | 2     | 2    |
| Output Control      | ~50         | ~30        | 0     | 0    |
| **Estimated Total** | **~6,400**  | **~4,600** | **8** | **6** |
| **% of Basys 3**    | **~31%**    | **~11%**   | **16%** | **7%** |

**Conclusion:** Design fits comfortably on Basys 3 with room for expansion.

## Target Hardware

**Development Board:** Digilent Basys 3

**FPGA:**
- Part: Artix-7 xc7a35tcpg236-1
- LUTs: 20,800
- Flip-Flops: 41,600
- Block RAM: 50 (36Kb each)
- DSP Slices: 90

**Peripherals:**
- Clock: 100 MHz onboard oscillator
- LEDs: 16 for status/debug
- Switches: For configuration
- I2S Microphone: External (ICS-43434 or similar)

## Module Interfaces

### Inference Engine (`inference.v`)

**Status:** Complete

```verilog
module inference (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  features [0:256],
    input  wire        features_valid,
    output reg         inference_done,
    output reg         prediction,
    output reg  [31:0] logits [0:1]
);
```

### Planned Module Interfaces

**I2S Receiver** (`i2s_rx.v` - TODO)
```verilog
module i2s_rx (
    input  wire        clk,           // System clock
    input  wire        rst_n,
    input  wire        i2s_sck,       // I2S serial clock
    input  wire        i2s_ws,        // I2S word select
    input  wire        i2s_sd,        // I2S serial data
    output reg  [15:0] sample,        // 16-bit audio sample
    output reg         sample_valid   // New sample ready
);
```

**Frame Buffer** (`frame_buffer.v` - TODO)
```verilog
module frame_buffer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sample_in,
    input  wire        sample_valid,
    output reg  [15:0] frame [0:511], // 512 samples
    output reg         frame_ready    // Frame complete
);
```

**FFT Core** (`fft_core.v` - TODO)
```verilog
module fft_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] time_data [0:511],
    input  wire        start,
    output reg  [31:0] freq_mag [0:255],  // Magnitude spectrum
    output reg         done
);
```

**Feature Extractor** (`feature_extractor.v` - TODO)
```verilog
module feature_extractor (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] fft_mag [0:255],
    input  wire        start,
    output reg  [7:0]  features [0:256],  // 257 INT8 features
    output reg         done
);
```

## Design Decisions

### Why INT8 Quantization?

- **Accuracy:** Minimal loss vs. float32 (~98% for both)
- **Resources:** 4× smaller memory footprint
- **Speed:** Integer arithmetic faster than floating-point
- **Power:** Lower dynamic power consumption

### Why Sequential MAC?

- **Area:** Single multiplier vs. 257 parallel multipliers
- **Timing:** Easier to meet timing at 100 MHz
- **Flexibility:** Easy to modify layer sizes
- **Trade-off:** Latency acceptable (3 μs << 32 ms frame time)

### Why Distributed RAM for Weights?

- **Async Reset:** BRAMs don't support async reset well
- **Access Pattern:** Random access during MAC
- **Size:** 8,768 bytes fits in distributed RAM
- **Trade-off:** Uses more LUTs but simplifies design

## Python Training Pipeline

### Scripts

1. **`collect_data.py`** - Record audio samples
2. **`make_features.py`** - Extract MFCC features
3. **`train_model.py`** - Train float32 Keras model
4. **`quantize_model.py`** - Convert to INT8 and generate `.mem` files
5. **`convert_test_vectors.py`** - Generate test cases
6. **`simulate_quantized_inference.py`** - Verify quantization

### Data Flow

```
Raw Audio → MFCC Features → Train Model → Quantize → .mem Files → Verilog
   (WAV)      (.npy)         (.h5)       (.npz)      (.mem)      (synthesis)
```

## References

- [INFERENCE.md](../fpga/INFERENCE.md) - Detailed inference module documentation
- [TODO.md](../fpga/rtl/TODO.md) - Audio pipeline implementation roadmap
- [project_status.md](project_status.md) - Current development status
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