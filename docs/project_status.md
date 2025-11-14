# Project Status

## Current State

### Completed Milestones
1. **Neural Network Model**: Trained 3-layer keyword spotting model (257→32→16→2)
   - Test accuracy: ~98%
   - Quantized to INT8 weights, INT32 biases

2. **Verilog Inference Module** (`fpga/rtl/inference.v`):
   - Complete 3-layer feedforward network with ReLU
   - INT8 quantization throughout
   - Icarus Verilog Simulation: 99% accuracy
   - Vivado Synthesis: Successful on Basys 3
     - Resource usage: 16.84% LUTs, 6.46% FFs
     - 0 errors, 0 critical warnings


## Missing Components

Audio pipeline (not yet implemented):
- `i2s_rx.v` - I2S receiver for MEMS microphone
- `frame_buffer.v` - 32ms audio windowing (512 samples @ 16kHz)  
- `fft_core.v` - 512-point FFT
- `feature_extractor.v` - Log-mel spectrogram → 257 features
- `top.v` - System integration with I/O for Basys 3

## Next Steps

### Build Audio Pipeline

Inference module is proven, 80%+ FPGA resources still available.

**Tasks**:
1. Implement I2S receiver for microphone interface
2. Create frame buffer for 32ms audio windows
3. Design FFT core (use Vivado IP or custom implementation)
4. Build feature extraction (mel filterbank + log)
5. Integrate: Audio → Features → Inference → Prediction

## Key Files
- Inference RTL: `fpga/rtl/inference.v`
- Testbench: `fpga/tb/tb_inference.v`
- Model weights: `models/mem/layer*.mem`
- Top-level: `fpga/rtl/top.v`

## Known Issues
- IOB overuse in synthesis: Expected, will resolve with proper top-level wrapper
- Weights in distributed RAM: By design (async reset), not a problem given resource headroom

## Target Hardware
- Board: Digilent Basys 3
- FPGA: Artix-7 xc7a35tcpg236-1
- Clock: 100 MHz
- Microphone: MEMS I2S (ICS-43434 or similar)
- Sample rate: 16 kHz
