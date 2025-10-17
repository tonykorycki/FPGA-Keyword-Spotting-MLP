# Development Notes

## Project Setup

### Development Environment
- Xilinx Vivado 2023.1
- Python 3.9+ with TensorFlow 2.10
- ModelSim/QuestaSim for simulation
- GTKWave for waveform viewing

### Hardware Setup
- Digilent Basys 3 FPGA board (Xilinx Artix-7)
- I2S MEMS microphone (SPH0645LM4H) connected to Pmod port
- Optional: External amplifier and speaker for audio feedback

## Implementation Notes

### FFT Implementation
- Using fixed-point arithmetic with Q8.8 format
- Radix-2 decimation-in-time algorithm
- Twiddle factors stored in ROM
- Consider using Xilinx FFT IP core for better performance

### Fixed-Point Representation
- Input audio: 16-bit signed
- FFT coefficients: 16-bit (Q8.8)
- Neural network weights: 8-bit signed (Q1.7)
- Activations: 8-bit signed (Q1.7)

### Neural Network Implementation
- Multiply-accumulate operations use DSP slices
- ReLU activation implemented with simple comparison
- Consider using DSP48 blocks for efficient MAC operations

## Testing Strategy

### Unit Tests
- Individual module tests with testbenches
- I2S interface: Test with synthetic patterns
- FFT: Test with sine waves and impulses
- Inference: Test with pre-computed feature vectors

### System Integration
- Loopback testing with recorded audio
- Measure real-time performance
- Verify proper clock domain crossing

## Known Issues & Limitations

1. The FFT implementation currently doesn't handle the DC bin correctly
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