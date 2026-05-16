# System Architecture

## Pipeline Overview

```
I2S Mic
  └─ i2s_rx.v              16-bit samples @ 16 kHz
       └─ frame_buffer.v   512-sample frames, 50% overlap, serial output
            └─ fft_core_v2.v   Xilinx xfft_0 (512-pt pipelined FFT), serial bin output
                 └─ feature_extractor_v2.v   magnitude → log2_approx → INT8 (257 bins)
                      └─ feature_averager.v  31-frame sliding window (~1 s)
                           └─ inference.v    3-layer MLP (257→32→16→2), INT8 weights
                                └─ top.v     LED output, ILA debug
```

All inter-module data flows serially (one sample or bin per clock cycle) over a handshake interface (`data`, `valid`, `ready`, `last`). This avoids wide parallel buses and makes BRAM-based buffering tractable on the Basys 3.

---

## Module Details

### i2s_rx.v — I2S Receiver

Captures 16-bit audio samples from a MEMS I2S microphone at 16 kHz. Outputs `audio_sample[15:0]` and `sample_valid` at the sample rate.

### frame_buffer.v — Audio Windowing

Accumulates 512 samples (32 ms at 16 kHz) and then streams them out one per clock cycle, 50% overlap between consecutive frames. Outputs `frame_sample[15:0]` + `frame_sample_valid` + `frame_consumed` handshake.

### fft_core_v2.v — 512-Point FFT

Wraps the Xilinx xfft_0 IP core (pipelined streaming FFT, Real Time throttle scheme). Accepts the serial frame from `frame_buffer`, feeds xfft_0, and streams output bins serially: `fft_bin_data[31:0]` ([31:16]=real, [15:0]=imag), `fft_bin_valid`, `fft_bin_last`.

`data_out_tready` is held HIGH at reset so the FFT output always drains — this prevents backpressure from stalling the IP's input-side tready (the root cause of an earlier hardware deadlock).

### feature_extractor_v2.v — Spectral Features

For each of the 257 output bins (DC through Nyquist): computes magnitude via integer approximation, applies log2 approximation, and requantizes to INT8. Streams `fft_feature_data[7:0]` + `fft_feature_valid` + `fft_feature_last`.

### feature_averager.v — Temporal Smoothing

Maintains a 31-frame sliding window ring buffer. Averages each of the 257 feature bins across the window (divide-by-32 via right shift, ~3.2% gain error — acceptable). Outputs `averaged_features[7:0]` + `averaged_valid`.

The ring buffer lives in distributed RAM (LUTs) rather than BRAM because the access pattern (simultaneous read of oldest + write of newest per bin) requires true dual-port access that Vivado cannot infer into block RAM. This uses ~815 LUTs and is a known optimization target.

### inference.v — MLP Inference Engine

Sequential MAC engine. Processes one multiply-accumulate per clock cycle.

| Layer | Input | Output | Weights | Activation |
|-------|-------|--------|---------|------------|
| 0 | 257 | 32 | 8,224 | ReLU |
| 1 | 32 | 16 | 512 | ReLU |
| 2 | 16 | 2 | 32 | None (logits) |

Weights and biases stored in block RAM, loaded from `.mem` files at bitstream load time. Output: `prediction` (1-bit), `inference_done`.

Inference latency: ~309 cycles @ 50 MHz = ~6 μs. Frame period: 32 ms. Headroom: >5,000×.

### top.v — Integration

Connects all modules, instantiates ILA debug core, drives Basys 3 LEDs on detection event. Reset is synchronous throughout.

---

## Quantization Scheme

| Quantity | Format | Notes |
|----------|--------|-------|
| Weights | INT8 (−127 to 127) | Stored in BRAM |
| Biases | INT32 | Full precision |
| Activations | INT8 | ReLU clipped |
| MAC Accumulator | INT32 | Per-layer, then requantized |

Requantization scale factors are computed offline during the Python quantization step and baked into the RTL as parameters.

---

## Resource Utilization

**Target:** Artix-7 xc7a35tcpg236-1, Vivado 2025.1, 50 MHz

Last implementation (design + ILA, with v1 fft/feature modules):

| Resource | Used | Available | % |
|----------|------|-----------|---|
| Slice LUTs | 19,010 | 20,800 | 91.4% |
| Slice Registers | 30,595 | 41,600 | 73.6% |
| Slices | 8,125 | 8,150 | 99.7% |

After v2 module migration (fft_core_v2 + feature_extractor_v2), the bin_real/bin_imag arrays and the 8224-bit parallel bus are eliminated (~8,261 FFs freed). New utilization pending re-synthesis.

**Timing:** WNS +0.313 ns with ILA (passes). Without ILA: WNS +1.047 ns.

---

## Clock Domain

Single clock domain: 50 MHz system clock derived from Basys 3's 100 MHz oscillator via BUFG.

Reset is synchronous throughout. The I2S bit clock is an input but all sampled data is re-registered on the system clock within i2s_rx.

---

## Python Training Pipeline

```
Raw WAV files  →  make_features.py  →  train_model.py  →  quantize_model.py  →  .mem files
(data/processed/)   (MFCC/log-spec)     (Keras, float32)    (INT8 weights)      (Vivado init)
```

Scripts:
- `collect_data.py` — microphone recording helper
- `make_features.py` — spectral feature extraction (matches RTL computation)
- `train_model.py` — Keras model training and evaluation
- `quantize_model.py` — INT8 quantization, scale factor computation, `.mem` file export
- `simulate_quantized_inference.py` — SW golden reference for RTL verification
- `convert_test_vectors.py` — generates hex test vectors for the Verilog testbench
