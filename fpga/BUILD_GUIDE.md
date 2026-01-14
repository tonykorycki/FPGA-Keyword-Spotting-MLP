# FPGA-KWS Build & Programming Guide
## Basys3 Keyword Spotting System

### Prerequisites
1. Vivado 2023.1+ installed
2. Basys3 board connected via USB
3. SPH0645 I2S MEMS microphone connected to Pmod JA

### Microphone Wiring (SPH0645 → Basys3 JA)
```
SPH0645 Pin    →    Basys3 JA Pin
-----------         -------------
VDD            →    VCC (3.3V)
GND            →    GND
BCLK           →    JA1 (J1)
LRCLK (WS)     →    JA2 (L2)
DOUT           →    JA3 (J2)
SEL            →    GND (Left channel)
```

---

## Option 1: Build in Vivado GUI

### Step 1: Open Project
1. Launch Vivado
2. File → Open Project
3. Navigate to: `C:\Users\koryc\fpga-kws\fpga\project\fpga_kws_inference\`
4. Open `fpga_kws_inference.xpr`

### Step 2: Update Sources (if RTL changed)
1. In Sources window, right-click "Design Sources"
2. Click "Refresh Hierarchy"

### Step 3: Run Synthesis
1. Click "Run Synthesis" in Flow Navigator
2. Wait for completion (~5-10 minutes)
3. Check for errors in Messages window

### Step 4: Run Implementation
1. Click "Run Implementation" 
2. Wait for completion (~10-15 minutes)
3. Check timing: should meet 100 MHz requirement

### Step 5: Generate Bitstream
1. Click "Generate Bitstream"
2. Wait for completion (~5 minutes)
3. Bitstream saved to: `.runs/impl_1/top.bit`

### Step 6: Program Board
1. Connect Basys3 via USB
2. Click "Open Hardware Manager"
3. Click "Auto Connect"
4. Right-click on device → "Program Device"
5. Select `top.bit`
6. Click "Program"

---

## Option 2: Build via TCL Script

```powershell
cd C:\Users\koryc\fpga-kws\fpga
vivado -mode tcl -source build.tcl
```

This will:
- Run synthesis
- Run implementation  
- Generate bitstream
- Copy bitstream to `C:\Users\koryc\fpga-kws\fpga_kws.bit`

---

## Testing on Hardware

### LED Indicators
| LED | Function |
|-----|----------|
| LED[0] | Audio sample received |
| LED[1] | Frame ready (512 samples) |
| LED[2] | FFT complete |
| LED[3] | Features extracted |
| LED[4] | Averaged features ready |
| LED[5] | Inference complete |
| LED[7] | Current prediction |
| LED[15] | Detection hold (stays on 500ms) |
| LED16 Blue | Processing active |
| LED16 Green | Inference running |
| LED16 Red | **KEYWORD DETECTED!** |

### Test Procedure
1. Program the board
2. LED[0] should blink rapidly (audio samples incoming)
3. LED[1-5] should light up in sequence
4. Say "START" clearly into the microphone
5. LED16 Red should light up for 500ms

### Troubleshooting
- **No LEDs blinking:** Check reset button (btnC), check microphone wiring
- **LED[0] not blinking:** Microphone not receiving BCLK/LRCLK
- **LED[2] stuck off:** FFT not completing - check FFT IP
- **False detections:** Adjust threshold via switches if implemented
- **Never detects:** Check microphone orientation (hole facing sound)

---

## Resource Usage (Expected)
- LUTs: ~15,000-20,000 / 20,800 (70-95%)
- FFs: ~8,000-12,000 / 41,600 (20-30%)
- BRAM: 20-30 / 50 (40-60%)
- DSP: 10-20 / 90 (10-20%)

---

## Files Modified Since Last Build
If you see synthesis errors, ensure these files are up to date:
- `fpga/rtl/feature_extractor.v` - Added << 3 scaling and [0,127] clamping
- `fpga/rtl/frame_buffer.v` - Fixed trigger logic
- `fpga/constraints/basys3.xdc` - Updated port names
