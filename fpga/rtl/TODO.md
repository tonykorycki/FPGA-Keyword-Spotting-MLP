# FPGA Keyword Spotting System - Architecture & Implementation Guide

## System Overview

This FPGA implementation performs real-time keyword spotting using a 3-layer neural network trained on audio features. The system processes audio from an I2S microphone, extracts frequency-domain features via FFT, and classifies the audio as "keyword" or "non-keyword" using quantized int8 inference.

### Data Flow Pipeline

```
Microphone → I2S RX → Frame Buffer → FFT → Feature Extraction → Neural Network → Output Control
   (analog)   (16-bit)   (256 samples)  (spectrum)  (257 int8)      (prediction)     (LEDs)
```

### Timing Budget (@ 100 MHz system clock)
- Audio sampling: 48 kHz (20.8 µs/sample)
- Frame generation: 256 samples @ 50% overlap = 2.67 ms/frame
- FFT computation: ~512 cycles = 5.12 µs
- Feature extraction: ~300 cycles = 3 µs
- Neural network inference: ~8,768 cycles = 87.68 µs
- **Total latency**: ~5.5 ms from audio to prediction

---

## Module Specifications

### 1. `i2s_rx.v` - I2S Audio Receiver

**Purpose**: Receive stereo audio samples from I2S microphone/ADC

**Inputs**:
- `clk` - System clock (100 MHz)
- `rst_n` - Active-low reset
- `i2s_sclk` - I2S serial bit clock (~1.536 MHz for 48kHz/16-bit)
- `i2s_lrclk` - I2S left/right channel clock (~48 kHz)
- `i2s_sdin` - I2S serial data input

**Outputs**:
- `audio_sample[15:0]` - 16-bit signed audio sample
- `sample_valid` - Single-cycle pulse when new sample ready
- `channel` - Channel indicator (0=left, 1=right)

**Behavior**:
1. Synchronize asynchronous I2S signals to system clock domain (2-stage synchronizer)
2. Detect SCLK rising edges for bit sampling
3. Shift in 16 bits MSB-first on each SCLK edge
4. After 16 bits collected, output complete sample with sample_valid pulse
5. Reset on LRCLK channel change

**Key Implementation Details**:
- Use 2-stage flip-flop synchronizers for clock domain crossing
- Sample data on SCLK rising edge per I2S standard
- Support both left and right channels (can select one for mono processing)
- Bit counter tracks position (0-15)

---

### 2. `frame_buffer.v` - Audio Frame Buffer

**Purpose**: Collect individual audio samples into fixed-size frames with overlap for FFT processing

**Inputs**:
- `clk` - System clock
- `rst_n` - Active-low reset
- `audio_sample[15:0]` - From i2s_rx
- `sample_valid` - From i2s_rx
- `frame_consumed` - Handshake from feature_extractor

**Outputs**:
- `frame_ready` - Pulse when 256 samples ready
- `frame_data[15:0][0:255]` - Array of 256 audio samples

**Behavior**:
1. Maintain circular buffer of 512 samples (double buffering)
2. Write new samples to buffer when sample_valid asserted
3. Generate frame_ready pulse every 128 samples (50% overlap)
4. Provide stable frame_data output while feature extractor is processing
5. Handle double buffering to allow simultaneous read/write

**Key Implementation Details**:
- Circular buffer with write pointer (0-511)
- Frame extraction starts at (write_ptr - 256) % 512
- 50% overlap provides better temporal resolution
- Handshake protocol prevents overwriting data being processed
- Optional: Apply Hamming/Hann window to reduce spectral leakage

---

### 3. `fft_core.v` - Fast Fourier Transform

**Purpose**: Convert time-domain audio frame to frequency-domain spectrum

**Inputs**:
- `clk` - System clock
- `rst_n` - Active-low reset
- `start` - Begin FFT computation
- `x_real[15:0][0:255]` - Real input (audio samples)
- `x_imag[15:0][0:255]` - Imaginary input (zeros for real-only input)

**Outputs**:
- `done` - FFT computation complete
- `y_real[15:0][0:255]` - Real part of FFT output
- `y_imag[15:0][0:255]` - Imaginary part of FFT output
- `valid` - Output data valid signal

**Behavior**:
1. Implement 256-point radix-2 Cooley-Tukey FFT
2. Bit-reverse input ordering
3. Execute 8 butterfly stages (log2(256) = 8)
4. Use pipelined or sequential architecture based on resource constraints
5. Assert done when all stages complete

**Key Implementation Details**:
- **RECOMMENDED**: Use Xilinx FFT IP Core from IP Catalog
  - Configurable for 256 points, 16-bit width
  - Pipelined or radix-2 burst I/O
  - Includes twiddle factor ROM
  - Optimized for Artix-7 FPGA
- Manual implementation requires:
  - Twiddle factor ROM (complex exponentials)
  - Complex butterfly units (4 real multiplies, 2 adds)
  - ~512 clock cycles for sequential, ~50 for pipelined
- Output is symmetric (bin[i] = conj(bin[256-i]) for real input)

---

### 4. `feature_extractor.v` - Feature Extraction

**Purpose**: Compute 257 magnitude values from FFT spectrum (neural network input features)

**Inputs**:
- `clk` - System clock
- `rst_n` - Active-low reset
- `frame_ready` - From frame_buffer
- `frame_data[15:0][0:255]` - From frame_buffer

**Outputs**:
- `features_ready` - Pulse when features computed
- `features[7:0][0:256]` - 257 int8 frequency magnitudes
- `frame_consumed` - Handshake back to frame_buffer

**Behavior**:
1. Start FFT when frame_ready asserted
2. Wait for FFT completion
3. For each of 257 FFT bins (DC to Nyquist + symmetric bins):
   - Compute magnitude: `mag = sqrt(real² + imag²)` or `mag² = real² + imag²`
   - Normalize/scale to int8 range [-127, 127]
4. Store in features array
5. Assert features_ready when all 257 features computed

**State Machine**:
- `IDLE`: Wait for frame_ready
- `START_FFT`: Initiate FFT core
- `WAIT_FFT`: Wait for FFT done signal
- `COMPUTE_MAG`: Compute magnitudes for all bins
- `NORMALIZE`: Scale to int8 range
- `DONE`: Assert features_ready, return to IDLE

**Key Implementation Details**:
- Magnitude computation can skip sqrt (use mag² for efficiency)
- Normalize by finding max magnitude, then scale: `int8_val = (mag * 127) / max_mag`
- Or use fixed scaling based on expected input range
- 257 features = 128 positive frequencies + DC + 128 negative (symmetric)
- For mono real input, could use only 129 bins (DC to Nyquist) - but model expects 257

---

### 5. `inference.v` - Neural Network Inference Engine

**Purpose**: Execute quantized 3-layer neural network for keyword classification

**Network Architecture**:
```
Layer 0: 257 inputs → 32 outputs (Dense + ReLU)
         Weights: 257×32 = 8,224 int8 values
         Biases: 32 int32 values

Layer 1: 32 inputs → 16 outputs (Dense + ReLU)
         Weights: 32×16 = 512 int8 values
         Biases: 16 int32 values

Layer 2: 16 inputs → 2 outputs (Dense, no activation)
         Weights: 16×2 = 32 int8 values
         Biases: 2 int32 values

Output: argmax([logit0, logit1]) → prediction (0 or 1)
```

**Inputs**:
- `clk` - System clock
- `rst_n` - Active-low reset
- `features[7:0][0:256]` - 257 int8 features from feature_extractor
- `features_valid` - Start inference

**Outputs**:
- `inference_done` - Computation complete
- `prediction` - Classification result (0=no keyword, 1=keyword)
- `logits[31:0][0:1]` - Raw output scores (optional, for debugging)

**Behavior**:

**Weight/Bias Memory**:
- Load from .mem files generated by Python quantization script
- `layer0_weights.mem` - 8,224 bytes (hex format)
- `layer0_bias.mem` - 128 bytes (32 int32 values, 4 bytes each)
- `layer1_weights.mem` - 512 bytes
- `layer1_bias.mem` - 64 bytes
- `layer2_weights.mem` - 32 bytes
- `layer2_bias.mem` - 8 bytes

**Sequential MAC Architecture** (Recommended for Basys 3):
```verilog
// Single Multiply-Accumulate unit reused for all computations
reg signed [7:0] weight, activation;
reg signed [31:0] accumulator;

// MAC operation (1 cycle)
accumulator <= accumulator + (weight * activation);
```

**State Machine**:
1. `IDLE`: Wait for features_valid
2. `LOAD_LAYER0`: Initialize Layer 0 computation
3. `MAC_LAYER0`: Execute 8,224 MACs (257 inputs × 32 outputs)
   - For each output neuron (32 total):
     - Initialize: `acc = bias[i]`
     - For each input (257 total):
       - `acc += feature[j] * weight[j][i]`
     - Requantize: `output[i] = clip((acc * requant_scale) >> SHIFT, -127, 127)`
     - Apply ReLU: `output[i] = max(0, output[i])`
4. `MAC_LAYER1`: Execute 512 MACs (32 × 16)
5. `MAC_LAYER2`: Execute 32 MACs (16 × 2)
6. `ARGMAX`: Compare logit[0] vs logit[1], output result
7. `DONE`: Assert inference_done, return to IDLE

**Requantization** (Critical!):
After each layer's MAC accumulation:
```verilog
// Accumulator is in scale: input_scale * weight_scale
// Need to scale back to int8 output range
wire signed [31:0] acc_scaled;
assign acc_scaled = (accumulator * REQUANT_SCALE_FIXED) >>> FRAC_BITS;

// Clip to int8 range
wire signed [7:0] output_clipped;
assign output_clipped = (acc_scaled > 127)  ? 8'd127 :
                        (acc_scaled < -127) ? -8'd127 :
                        acc_scaled[7:0];
```

**Requantization Scale Parameters** (from scales.json):
- Load requant_scale as fixed-point (e.g., Q16.16 format)
- Example: `requant_scale_fp = int(requant_scale_float * 65536)`
- Store in ROM or parameter

**Key Implementation Details**:
- Total MAC operations: 8,224 + 512 + 32 = 8,768
- At 100 MHz: 87.68 µs per inference (11,400 inferences/sec)
- Memory usage: ~9 KB weights + ~200 bytes biases (fits in BRAM)
- Use single MAC unit to minimize LUT usage (no DSPs on Basys 3)
- Weight memory addressing: Sequential layout, increment pointer each MAC
- ReLU: Simple comparison and mux (`output = (x > 0) ? x : 0`)
- Final argmax: Compare two int32 logits, output binary result

**Optimization Options** (if resources allow):
- Parallel MACs: Use 4-8 MAC units → 4-8× speedup
- Pipeline stages: MAC → Requantize → ReLU
- Sparsity: Skip multiplications for zero weights

---

### 6. `output_control.v` - Output Control & Visualization

**Purpose**: Drive LEDs and output signals based on detection results

**Inputs**:
- `clk` - System clock
- `rst_n` - Active-low reset
- `inference_done` - From inference engine
- `prediction` - From inference engine (0 or 1)

**Outputs**:
- `led[15:0]` - 16 LEDs on Basys 3 board
- `detected` - Detection signal (can drive external relay/buzzer)

**Behavior**:
1. When `prediction == 1` (keyword detected):
   - Set `detected` HIGH
   - Light LEDs in pattern (e.g., all on, chase, pulse)
   - Hold for configurable time (e.g., 100ms)
2. When `prediction == 0`:
   - Clear `detected`
   - Show idle pattern (e.g., single LED, breathing)
3. Optional: Show system status on LEDs
   - LED[0]: I2S receiving
   - LED[1]: Frame ready
   - LED[2]: FFT processing
   - LED[3]: Inference running
   - LED[15]: Keyword detected

**Key Implementation Details**:
- Detection hold timer: ~5,000,000 cycles @ 100MHz = 50ms
- LED animation counter for visual effects
- Debouncing: Require multiple consecutive detections to avoid false triggers
- Optional confidence threshold from logit difference

---

### 7. `top.v` - Top-Level Integration

**Purpose**: Instantiate and connect all modules, map to Basys 3 pins

**Inputs** (from Basys 3 constraints):
- `clk` - 100 MHz system clock (W5)
- `rst_n` - Reset button (active-low)
- `i2s_sclk` - I2S bit clock from microphone
- `i2s_lrclk` - I2S word select from microphone
- `i2s_sdin` - I2S data from microphone

**Outputs**:
- `led[15:0]` - 16 LEDs (U16, E19, U19, etc.)
- `detected` - Detection output (can use RGB LED or Pmod pin)

**Module Instantiation**:
```verilog
// Audio input
wire [15:0] audio_sample;
wire sample_valid;
i2s_rx i2s_inst (...);

// Frame buffering
wire frame_ready;
wire [15:0] frame_data [0:255];
frame_buffer fb_inst (...);

// Feature extraction
wire features_ready;
wire [7:0] features [0:256];
feature_extractor feat_inst (...);

// Neural network inference
wire inference_done;
wire prediction;
inference inf_inst (...);

// Output control
output_control out_inst (...);
```

**Signal Routing**:
- i2s_rx.audio_sample → frame_buffer.audio_sample
- frame_buffer.frame_data → feature_extractor.frame_data
- feature_extractor.features → inference.features
- inference.prediction → output_control.prediction

**Clock Management**:
- Use 100 MHz input clock directly (no PLL needed for basic version)
- Optional: Add PLL to generate optimal FFT clock frequency

**Key Implementation Details**:
- Add synchronous reset generation from async button
- Consider clock enable for power optimization
- Add debug outputs (chipscope/ILA triggers)

---

## Resource Utilization Estimates (Basys 3 - Artix-7 35T)

| Module | LUTs | FFs | BRAM | DSP |
|--------|------|-----|------|-----|
| i2s_rx | ~50 | ~40 | 0 | 0 |
| frame_buffer | ~100 | ~100 | 1 (512 samples) | 0 |
| fft_core (IP) | ~800 | ~600 | 2-4 | 0 |
| feature_extractor | ~300 | ~200 | 0 | 0 |
| inference | ~1500 | ~800 | 2-3 (weights) | 0 |
| output_control | ~50 | ~50 | 0 | 0 |
| **Total** | **~2800** | **~1800** | **5-8** | **0** |
| **Available** | 20,800 | 41,600 | 90 | 0 |
| **Utilization** | 13% | 4% | 9% | N/A |

✅ **Should fit comfortably on Basys 3**

---

## Testing Strategy

### Module-Level Testbenches
1. `i2s_rx_tb.v` - Verify I2S bit reception, check sample reconstruction
2. `frame_buffer_tb.v` - Test frame assembly, overlap handling
3. `fft_core_tb.v` - Compare against Python FFT (numpy.fft)
4. `feature_extractor_tb.v` - Verify magnitude computation, scaling
5. `inference_tb.v` - Use test_input.npy and test_output.npy from Python
6. `top_tb.v` - Full system simulation with audio file input

### Golden Reference Testing
- Python script generates: `test_input.npy` (100 feature vectors)
- Python script generates: `test_output.npy` (100 predictions)
- Verilog testbench loads inputs, compares outputs
- Require 100% match for correctness

### Hardware Validation
1. Load bitstream to Basys 3
2. Connect I2S microphone
3. Speak keyword, verify LED lights
4. Speak non-keyword, verify LED stays off
5. Measure latency with oscilloscope (mic input to LED output)

---

## File Dependencies & Build Order

```
1. i2s_rx.v (no dependencies)
2. frame_buffer.v (no dependencies)
3. fft_core.v (Xilinx IP - generate via IP Catalog)
4. feature_extractor.v (depends on fft_core)
5. inference.v (depends on .mem files from Python)
6. output_control.v (no dependencies)
7. top.v (depends on all above)
```

**Python Prerequisites**:
- Run `quantize_model.py` to generate:
  - `models/mem/*.mem` files (weights/biases in hex)
  - `models/scales.json` (requantization parameters)
  - `models/test_input.npy` (validation vectors)
  - `models/test_output.npy` (golden predictions)

---

## Implementation Roadmap

### Phase 1: Audio Pipeline (Week 1)
- [ ] Implement `i2s_rx.v`
- [ ] Test with I2S mic or signal generator
- [ ] Implement `frame_buffer.v`
- [ ] Verify 256-sample frames with overlap

### Phase 2: Feature Extraction (Week 2)
- [ ] Add Xilinx FFT IP core
- [ ] Implement `feature_extractor.v`
- [ ] Test against Python FFT outputs
- [ ] Verify 257 int8 features match expected range

### Phase 3: Neural Network (Week 3)
- [ ] Implement `inference.v` with weight loading
- [ ] Add requantization logic
- [ ] Test with golden vectors from Python
- [ ] Verify 98%+ accuracy match

### Phase 4: Integration & Testing (Week 4)
- [ ] Implement `output_control.v`
- [ ] Integrate all modules in `top.v`
- [ ] Synthesize and meet timing @ 100 MHz
- [ ] Hardware testing with real audio

### Phase 5: Optimization (Optional)
- [ ] Add parallel MAC units for speedup
- [ ] Optimize BRAM usage
- [ ] Add confidence thresholding
- [ ] Power optimization (clock gating)

---

## Success Criteria

1. ✅ Synthesizes without errors on Basys 3
2. ✅ Meets timing @ 100 MHz
3. ✅ Uses <15,000 LUTs, <10 BRAMs
4. ✅ Inference matches Python simulation (98%+ agreement)
5. ✅ Real-time performance: <10ms latency
6. ✅ Detects keyword with >90% accuracy in hardware
7. ✅ Low false positive rate (<5% on non-keyword audio)
