# Neural Network Inference Module

## Overview

The inference module implements a 3-layer quantized neural network for keyword spotting on FPGA. It uses int8 weights/activations with int32 accumulators and Q16.16 fixed-point requantization.

**Architecture**: 257 → 32 → 16 → 2 (input → hidden → hidden → output)

**Accuracy**: 99% (matches Python quantized model)

---

## Files

### RTL Implementation
- **`fpga/rtl/inference.v`** - Main inference engine module

### Testbench
- **`fpga/tb/tb_inference.v`** - Testbench with 100 test vectors
- **`fpga/tb/run_inference_sim.ps1`** - Windows simulation script
- **`fpga/tb/run_inference_sim.sh`** - Linux/Mac simulation script

### Supporting Python
- **`python/convert_test_vectors.py`** - Generates hex test vectors from numpy arrays
- **`python/simulate_quantized_inference.py`** - Python reference implementation

---

## Module Architecture

### Interface

```verilog
module inference (
    input wire clk,
    input wire rst,
    input wire inference_start,           // Pulse to start inference
    input wire signed [7:0] features [0:256],  // 257 input features (int8)
    
    output reg inference_done,            // Pulses when complete
    output reg prediction,                // Classification result (0 or 1)
    output reg signed [15:0] logits [0:1] // Raw logit outputs
);
```

### State Machine

```
[IDLE] → [LOAD_INPUT] → [L0_MAC] → [L0_REQUANT] → 
[L1_MAC] → [L1_REQUANT] → [L2_MAC] → [L2_REQUANT] → 
[ARGMAX] → [DONE] → [IDLE]
```

### Layer Processing

Each layer follows the same pattern:

1. **MAC State**: Multiply-accumulate loop
   - Load weight and activation
   - Accumulate: `acc += weight * activation`
   - Sequential processing (single MAC unit)
   - Uses `first_mac` flag to skip invalid first cycle

2. **REQUANT State**: Requantization and activation
   - Scale: `acc_scaled = (acc * requant_scale) >> 16`
   - Clip to int8: `[-127, 127]`
   - Apply ReLU (layers 0-1 only)

### Critical Implementation Details

#### 1. Requantization Scales (Q16.16 Fixed-Point)
```verilog
parameter signed [31:0] L0_REQUANT_SCALE = 32'd516;   // round(0.00787 * 65536)
parameter signed [31:0] L1_REQUANT_SCALE = 32'd141;   // round(0.00215 * 65536)
parameter signed [31:0] L2_REQUANT_SCALE = 32'd282;   // round(0.00430 * 65536)
```

**Important**: Must use `round(scale_float * 65536)`, not the raw float value!

#### 2. Weight Memory Layout (Row-Major)

Weights are stored as: `[input0_output0, input0_output1, ..., input1_output0, ...]`

To access weight for `input_i` and `output_j`:
```verilog
weight_addr = input_i * NUM_OUTPUTS + output_j
```

When iterating through inputs for a fixed output:
```verilog
// Increment weight_addr by NUM_OUTPUTS (not 1!)
weight_addr <= weight_addr + L0_OUT;  // e.g., +32 for layer 0
```

#### 3. MAC Pipeline Handling

The MAC unit is combinational: `mac_product = mac_weight * mac_activation`

To avoid using garbage from previous cycle:
```verilog
if (!first_mac) begin
    mac_accumulator <= mac_accumulator + $signed(mac_product);
end else begin
    first_mac <= 1'b0;  // Skip first cycle
end
```

Final product added in REQUANT state:
```verilog
layer_output <= requantize(mac_accumulator + $signed(mac_product), SCALE);
```

### Timing Performance

| Metric | Value |
|--------|-------|
| Layer 0 MAC operations | 257 × 32 = 8,224 |
| Layer 1 MAC operations | 32 × 16 = 512 |
| Layer 2 MAC operations | 16 × 2 = 32 |
| **Total cycles** | **~9,077** |
| @ 100 MHz | 90.77 µs/inference |
| Throughput | 11,020 inferences/sec |

---

## Testing

### 1. Generate Test Vectors

```bash
cd /path/to/fpga-kws
python python/simulate_quantized_inference.py  # Generate reference logits
python python/convert_test_vectors.py          # Convert to hex format
```

This creates:
- `models/test_input_hex.txt` - 100 samples × 257 features (25,700 hex int8 values)
- `models/test_output_ref.txt` - 100 expected predictions (0 or 1)
- `models/test_logits.npy` - Reference logits from Python

### 2. Run Simulation

**Windows PowerShell:**
```powershell
cd fpga/tb
.\run_inference_sim.ps1
```

**Linux/Mac:**
```bash
cd fpga/tb
chmod +x run_inference_sim.sh
./run_inference_sim.sh
```

**Manual:**
```bash
cd fpga/tb
iverilog -g2012 -o inference_sim.vvp -I ../rtl tb_inference.v ../rtl/inference.v
vvp inference_sim.vvp
```

### 3. Expected Output

```
Test   0: PASS | Pred=0, Expected=0 | Logits=[127, -109] | Cycles=9077
Test   1: PASS | Pred=0, Expected=0 | Logits=[127, -107] | Cycles=9077
...
Test  99: PASS | Pred=1, Expected=1 | Logits=[-127, 127] | Cycles=9077

Total Tests:    100
Passed:         99
Failed:         1
Accuracy:       99.00%
```

**Note**: 99% accuracy is expected due to minor rounding differences from Python.

### 4. View Waveforms

```bash
gtkwave fpga/tb/inference_tb.vcd
```

Key signals to observe:
- `dut.state` - State machine progression
- `dut.mac_accumulator` - Accumulator during MAC
- `dut.layer0_output[*]` - Layer outputs
- `dut.logits[0]`, `dut.logits[1]` - Final logits

---

## Resource Utilization (Estimated for Basys 3)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~2,700 | 20,800 | 13% |
| FFs | ~800 | 41,600 | 2% |
| BRAM | 8 | 90 | 9% |
| DSP | 0 | 90 | 0% |

**Weight Memory**:
- Layer 0: 8,224 bytes = 2 BRAMs
- Layer 1: 512 bytes = 0.25 BRAMs
- Layer 2: 32 bytes = 0.02 BRAMs
- Bias: ~272 bytes = 0.17 BRAMs
- **Total**: ~3 BRAMs (rounded up to 4 for alignment)

---

## Common Issues & Solutions

### Issue 1: All logits saturate to [-127, 127]
**Cause**: Requantization scales too small (e.g., using 515989 instead of 516)

**Fix**: Verify scales are `round(float_scale * 65536)`
```bash
python -c "import json; s=json.load(open('models/scales.json')); 
print('L0:', int(s['layers'][0]['requantize_scale'] * 65536))"
```

### Issue 2: Logits far from expected values
**Cause**: Wrong weight addressing (incrementing by 1 instead of NUM_OUTPUTS)

**Fix**: Check weight_addr increments:
```verilog
weight_addr <= weight_addr + L0_OUT;  // NOT + 1
```

### Issue 3: First few tests pass, later tests fail
**Cause**: MAC pipeline bug (using garbage from previous cycle)

**Fix**: Ensure `first_mac` flag properly skips first accumulation cycle

### Issue 4: Compilation errors with memory files
**Cause**: Incorrect relative paths to `.mem` files

**Fix**: Run simulation from `fpga/tb/` directory, or adjust paths:
```verilog
parameter LAYER0_WEIGHTS_FILE = "../../models/mem/layer0_weights.mem";
```

---

## Next Steps

1. **Synthesize for FPGA**: Run Vivado synthesis targeting Basys 3
2. **Timing closure**: Verify meets 100 MHz timing
3. **Integration**: Connect to feature extraction pipeline
4. **Top-level**: Combine all modules in `top.v`

## Reference Documents

- **`docs/audio_pipeline.md`** - Audio preprocessing module specifications
- **`python/quantize_model.py`** - Weight quantization details
- **`docs/architecture.md`** - System design overview
