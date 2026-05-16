# Project Status

_Last updated: May 2026_

## Current State

Full RTL pipeline is implemented and synthesized. The system is in hardware integration testing.

### Completed

| Milestone | Details |
|-----------|---------|
| Python ML pipeline | Data collection, feature extraction, Keras training |
| INT8 quantization | 8,768 weights quantized, `.mem` files generated for Vivado |
| Verilog inference engine | 3-layer MLP (257→32→16→2), 99% simulation accuracy |
| Audio preprocessing RTL | i2s_rx, frame_buffer, fft_core_v2, feature_extractor_v2, feature_averager |
| System integration | top.v wires all modules; synchronous reset throughout |
| Vivado synthesis + implementation | Passes timing at 50 MHz on Basys 3 (xc7a35tcpg236-1) |
| ILA debug infrastructure | 28 internal signals exposed for on-chip logic analysis |

### In Progress

- **Hardware verification via ILA** — verifying the full pipeline produces valid predictions on live audio. Trigger sequence: config_done → fft_ready → fft_bin_last → inference_done.

### Pending (next steps)

1. Vivado: regenerate xfft_0 IP with **Real Time** throttle scheme, add v2 source files, disable v1 files
2. Run full (non-incremental) synthesis + implementation after v2 migration
3. Program board and capture ILA traces to confirm end-to-end dataflow
4. Update `tb_handshake_chain.v` for the v2 serial interface
5. Long-term: pipeline the inference MAC to achieve ≥3 ns timing margin

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Float32 model accuracy | ~98% on test set |
| INT8 quantized accuracy | ~98% on test set |
| Verilog simulation accuracy | 99% (797/800 test vectors) |
| Clock | 50 MHz |
| Inference latency | ~6 μs (309 MAC cycles) |
| Audio frame period | 32 ms |
| Slice LUT utilization | 91.4% (with ILA) |
| Timing margin (WNS) | +0.313 ns at 50 MHz |

---

## Known Limitations

**Slice utilization is high (~99.7% with ILA).** The main driver is the feature averager's 31-frame ring buffer in distributed RAM (~815 LUTs). Migrating it to a single-port BRAM FSM would recover significant area. The v2 serial module migration also frees ~8,261 FFs once re-synthesized.

**Timing margin is thin (+0.313 ns with ILA).** Adequate for development but insufficient for temperature/voltage variation in production. Options: reduce clock to 25 MHz, or pipeline the inference MAC across multiple stages.

**Clock is 50 MHz, not 100 MHz.** The inference MAC accumulates over 24 logic levels; 100 MHz gave WNS = −7.097 ns. 50 MHz passes with margin.
