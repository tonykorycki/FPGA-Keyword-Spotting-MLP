# FPGA Keyword Spotting

A complete keyword spotting system built from scratch — from recording training data to running a quantized neural network on an FPGA in real time.

The system listens for the word "start" through an I2S microphone, runs the audio through a 512-point FFT and feature extraction pipeline, and classifies each frame using an INT8-quantized neural network.

**Hardware:** Digilent Basys 3 (Artix-7 xc7a35tcpg236-1)

---

## What's in here

**Python side:** data collection, spectral feature extraction, model training (Keras), INT8 quantization, and exporting weights as Verilog memory init files.

**FPGA side:** a complete RTL audio processing pipeline:

```
I2S Mic → Frame Buffer → 512-pt FFT → Feature Extraction → MLP Inference → LED Output
```

Each stage streams data serially to the next using a handshake interface, so the pipeline runs continuously without stalling. A 31-frame sliding window averages features over ~1 second before inference to suppress noise.

---

## The neural network

A 3-layer INT8 MLP trained on custom-recorded audio:

| Layer | Shape | Activation |
|-------|-------|------------|
| Dense 0 | 257 → 32 | ReLU |
| Dense 1 | 32 → 16 | ReLU |
| Dense 2 | 16 → 2 | — (logits) |

- Float32 accuracy: **~98%** on test set  
- After INT8 quantization: **~98%** (negligible accuracy loss)  
- Verilog simulation: **99%** (797/800 test vectors pass)

Weights are stored in block RAM and loaded at bitstream time from `.mem` files generated during quantization.

---

## Fitting it on a Basys 3

The Basys 3 is a small board (20,800 LUTs, 50 BRAM blocks). Getting the full pipeline to fit required several non-obvious decisions:

**Serial dataflow between modules.** Rather than passing wide parallel buses (e.g., 512 × 16-bit = 8,192 wires for a frame), each module streams one sample or bin per clock cycle. This keeps routing manageable and lets Vivado infer BRAM for the internal buffers.

**Downclocking to 50 MHz.** The inference MAC spans 24 logic levels. At 100 MHz the worst-case path failed by 7 ns. At 50 MHz it passes with 0.3 ns margin — plenty for development.

**INT8 throughout.** 8,768 weights × 8 bits = 70 KB, which fits in on-chip BRAM. The same weights in float32 would be 280 KB — more than the Basys 3's entire BRAM capacity.

**Xilinx FFT IP with real-time throttle.** The pipelined streaming FFT backpressures its own input if the output isn't being consumed. This caused a complete hardware deadlock on first bring-up (ILA showed the design sitting motionless after reset). The fix was to keep `data_out_tready` asserted at reset so output always drains.

Final resource utilization (with ILA debug core attached):

| Resource | Used | Available | % |
|----------|------|-----------|---|
| Slice LUTs | 19,010 | 20,800 | 91% |
| Registers | 30,595 | 41,600 | 74% |
| Timing (WNS) | +0.313 ns | — | passes |

---

## Status

Full RTL pipeline is implemented and synthesized. Currently in hardware bring-up using Vivado's ILA logic analyzer to verify each stage of the pipeline produces valid data on real audio.

---

## Running it yourself

**Train the model:**
```bash
pip install -r requirements.txt
python python/make_features.py    # extract features from data/processed/
python python/train_model.py      # train and evaluate
python python/quantize_model.py   # INT8 quantization, writes models/mem/*.mem
```

**Simulate:**
```powershell
cd fpga
iverilog -g2012 -o sim/tb.vvp `
    tb/tb_handshake_chain.v rtl/frame_buffer.v `
    rtl/fft_core_v2.v rtl/feature_extractor_v2.v rtl/xfft_0_stub.v
vvp sim/tb.vvp
```

**Synthesize:** Open `fpga/project/fpga_kws_inference/fpga_kws_inference.xpr` in Vivado 2025.1. Regenerate the xfft_0 IP with **Throttle Scheme: Real Time** before building.

---

