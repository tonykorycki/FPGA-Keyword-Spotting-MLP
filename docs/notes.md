# Development Notes

## Project Setup (October 2025)

### Development Environment
- **Vivado:** 2025.1 (Windows)
- **Python:** 3.8+ with TensorFlow 2.x, librosa, numpy
- **Simulation:** Icarus Verilog (for RTL sim), Vivado XSim (optional)
- **Waveforms:** GTKWave (or Vivado waveform viewer)
- **Version Control:** Git with GitHub

### Hardware
- **Target Board:** Digilent Basys 3 (Artix-7 xc7a35tcpg236-1)
- **Clock:** 100 MHz onboard oscillator
- **Microphone:** I2S MEMS (ICS-43434 or similar) - not yet connected
- **Debugging:** LEDs, switches for status display

## Current Implementation Status

### Completed Modules

**Inference Engine (`inference.v`):**
- 3-layer MLP: 257→32→16→2
- INT8 quantized weights
- Sequential MAC architecture
- Requantization with Q16.16 scale factors
- ReLU activation
- Argmax classification
- Status: Tested, synthesized, verified

**Python Pipeline:**
- Audio data collection and preprocessing
- MFCC feature extraction (257 coefficients)
- Model training (Keras/TensorFlow)
- INT8 quantization with scale factor computation
- Memory file generation (.mem format)
- Test vector generation and validation
- Status: Complete

### In Progress / TODO

**Audio Preprocessing Pipeline:**
- `i2s_rx.v` - I2S microphone interface
- `frame_buffer.v` - Windowing and buffering
- `fft_core.v` - 512-point FFT
- `feature_extractor.v` - Mel-spectrogram
- `top.v` - System integration
- `output_control.v` - LED/output control

See [audio_pipeline.md](audio_pipeline.md) for detailed specs.

## Fixed-Point Representation

### Audio Data
- **Input audio:** 16-bit signed PCM (I2S from microphone)
- **Sample rate:** 16 kHz
- **Frame size:** 512 samples (32 ms)

### Neural Network
- **Weights:** INT8 signed (-127 to 127)
- **Biases:** INT32 full precision
- **Activations:** INT8 signed with ReLU clipping
- **Accumulator:** INT32 for MAC operations
- **Requantization:** Q16.16 scale factors

**Quantization scales (from `scales.json`):**
```
Layer 0: 0.007874 → 516 (Q16.16)
Layer 1: 0.002152 → 141 (Q16.16)
Layer 2: 0.004304 → 282 (Q16.16)
```

### FFT (Planned)
- **Input:** 16-bit signed samples
- **Twiddle factors:** To be determined (likely Q2.14 or ROM-based)
- **Output:** Magnitude spectrum, scaled to INT8 features
- **Implementation:** Consider Vivado FFT IP vs. custom RTL

## Implementation Decisions

### Why Sequential MAC?
- **Trade-off:** Latency vs. area
- **Benefit:** Only one multiplier needed (vs. 257 parallel)
- **Acceptable:** 5.66 μs << 32 ms frame time (5,677× margin)
- **Flexibility:** Easy to modify layer sizes

### Why Distributed RAM for Weights?
- **Reason:** Async reset incompatible with BRAM inference
- **Trade-off:** Uses more LUTs but simpler design
- **Size:** 8.8 KB fits easily in distributed RAM
- **Future:** Could migrate to BRAM for LUT savings

### Why No DSP Slices?
- **Design choice:** Implement MAC in fabric logic
- **Benefit:** Saves DSPs for FFT (which needs them more)
- **Trade-off:** Slightly slower, but still plenty fast
- **Future:** Could use DSP48s for optimization

## Testing Strategy

### Unit Tests

**Inference Engine:**
- 800 test vectors from Python quantized model
- Icarus Verilog simulation: 99.625% accuracy (797/800)
- Compare against Python golden reference
- Edge case testing (min/max values, overflow)

**Future Module Tests:**
- I2S receiver: Test with synthetic bit patterns
- FFT: Verify with sine waves, impulses, noise
- Feature extractor: Compare with librosa MFCC output
- Full pipeline: End-to-end audio file playback

### Integration Testing

**Planned:**
1. Loopback test with recorded audio samples
2. Real-time microphone input testing
3. False positive/negative rate analysis
4. Timing verification (clock domain crossing)
5. Power consumption measurement

## Known Issues & Lessons Learned

### Issue 1: BRAM vs. Distributed RAM
**Problem:** Initial design used BRAMs for weights, but async reset caused synthesis warnings.  
**Solution:** Migrated to distributed RAM (FFs).  
**Impact:** Uses more LUTs but design is cleaner.  
**Future:** Add synchronous reset to use BRAMs.

### Issue 2: Requantization Overflow
**Problem:** Direct INT32→INT8 conversion caused overflow.  
**Solution:** Added clipping to [-127, 127] range in requantize function.  
**Impact:** Prevents saturation artifacts in activations.

### Issue 3: Test Vector Mismatch
**Problem:** Initial Verilog sim had 5% error rate vs. Python.  
**Solution:** Fixed signed/unsigned type mismatches in MAC.  
**Result:** Improved to 99.625% match.

### Lesson: Quantization Matters
- Scale factors are critical for accuracy
- Must match Python and Verilog exactly
- Test with extreme values to catch overflow

### Lesson: Simulation is Essential
- Caught multiple bugs before synthesis
- Test vectors from Python give confidence
- Waveform debugging invaluable for MAC timing

## Debugging Tips

### Simulation Debugging
1. **Use VCD dumps:** `$dumpfile()` and `$dumpvars()` in testbench
2. **Add debug signals:** Output intermediate layer values
3. **Compare incrementally:** Test one layer at a time
4. **Check signs:** Ensure `$signed()` used correctly
5. **Watch for X/Z:** Uninitialized signals cause silent failures

### Synthesis Debugging
1. **Check synthesis warnings:** Even "info" messages matter
2. **Review utilization report:** Unexpected BRAM/DSP usage indicates issues
3. **Examine critical paths:** Identify timing bottlenecks
4. **Use ILA (integrated logic analyzer):** For on-chip debugging

### Python-Verilog Matching
1. **Print intermediate values:** In both Python and Verilog
2. **Match bit widths exactly:** Truncation differs between languages
3. **Test corner cases:** Max/min values, zero, overflow
4. **Use hex format:** Easier to compare than decimal

## Optimization Ideas (Future)

### Performance
- **Pipeline MAC:** Add registers between multiply and accumulate
- **Parallel layers:** Compute multiple neurons simultaneously
- **Clock boost:** Increase to 150-200 MHz with timing constraints
- **DSP slices:** Use for MAC to improve speed/area

### Resources
- **BRAM migration:** Move weights to block RAM (save LUTs)
- **Sparse weights:** Skip zero-weight multiplications
- **Pruning:** Remove low-weight connections
- **Weight sharing:** Reduce unique weight values

### Power
- **Clock gating:** Disable unused modules
- **Reduced precision:** Try INT4 for some layers
- **Activity detection:** Only run inference when audio detected
- **Power domains:** Separate always-on and inference logic

## File Organization Best Practices

### Version Control
- Track source RTL, testbenches, Python scripts
- Ignore Vivado build artifacts (`.runs/`, `.sim/`, `.cache/`)
- Keep one copy of weights (in `models/mem/`)
- Use descriptive commit messages

### Documentation
- Keep `project_status.md` updated with milestones
- Document design decisions in `notes.md`
- Update `architecture.md` when adding modules
- Maintain `TODO.md` for roadmap clarity

### Code Style
- Use consistent indentation (4 spaces)
- Comment complex logic blocks
- Name signals descriptively (`mac_accumulator` not `acc`)
- Group related signals together

## Resources & References

### Vivado
- [Vivado Design Suite User Guide](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2025_1/ug893-vivado-ides.pdf)
- [Artix-7 FPGAs Data Sheet](https://www.xilinx.com/support/documentation/data_sheets/ds181_Artix_7_Data_Sheet.pdf)
- [Basys 3 Reference Manual](https://digilent.com/reference/programmable-logic/basys-3/reference-manual)

### Quantization
- [TensorFlow Lite Quantization](https://www.tensorflow.org/lite/performance/quantization_spec)
- [Quantization and Training of Neural Networks for Efficient Integer-Arithmetic-Only Inference](https://arxiv.org/abs/1712.05877)

### DSP
- [Understanding Digital Signal Processing (Lyons)](https://www.amazon.com/Understanding-Digital-Signal-Processing-3rd/dp/0137027419)
- [The Scientist and Engineer's Guide to Digital Signal Processing](http://www.dspguide.com/)

### I2S
- [I2S Bus Specification](https://www.sparkfun.com/datasheets/BreakoutBoards/I2SBUS.pdf)
- [ICS-43434 Datasheet](https://www.invensense.com/products/digital/ics-43434/)

## Next Steps

**Short Term (1-2 weeks):**
1. Design I2S receiver module
2. Create frame buffer with Hamming window
3. Research FFT implementation options (IP vs. custom)

**Medium Term (1-2 months):**
1. Implement FFT core (512-point)
2. Design mel-filterbank feature extractor
3. Integrate audio pipeline with inference engine
4. Create top-level module and constraints

**Long Term (3+ months):**
1. Hardware testing on Basys 3 board
2. Real-time audio validation
3. Power measurement and optimization
4. Documentation and demo videos

## Contact & Collaboration

**Author:** Tony Korycki  
**Project:** fpga-kws  
**Repository:** github.com/tonykorycki/fpga-kws  
**Last Updated:** October 31, 2025
2. Frame overlap processing needs optimization for timing closure
3. Detection threshold may need tuning for different environments

## Future Work

- Add power management features
- Implement multiple keyword detection
- Optimize for lower resource utilization
- Consider using HLS for feature extraction
- Add serial interface for external control

## Resources & References

- [Xilinx DSP48 User Guide](https://www.xilinx.com/support/documentation/user_guides/ug479_7Series_DSP48E1.pdf)
- [I2S Specification](https://web.archive.org/web/20070102004400/http://www.nxp.com/acrobat_download/various/I2SBUS.pdf)
- [MFCC Feature Extraction](https://haythamfayek.com/2016/04/21/speech-processing-for-machine-learning.html)
- [Fixed-Point Neural Networks](https://arxiv.org/abs/1712.01917)