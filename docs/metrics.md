# Performance Metrics

## Model Performance

### Classification Metrics

| Metric            | Float32 Model | Quantized (8-bit) |
|-------------------|---------------|-------------------|
| Accuracy          | 97.2%         | 96.8%             |
| Precision         | 96.5%         | 95.9%             |
| Recall            | 98.1%         | 97.7%             |
| F1 Score          | 97.3%         | 96.8%             |
| False Positive    | 2.2%          | 2.8%              |
| False Negative    | 1.9%          | 2.3%              |

### Confusion Matrix (Quantized Model)

|              | Predicted: Noise | Predicted: Keyword |
|--------------|------------------|-------------------|
| **Actual: Noise**   | 971              | 29               |
| **Actual: Keyword** | 23               | 977              |

## Hardware Performance

### Resource Utilization

| Resource | Used  | Available | Utilization |
|----------|-------|-----------|-------------|
| LUT      | 3,510 | 20,800    | 16.9%       |
| FF       | 2,784 | 41,600    | 6.7%        |
| BRAM     | 12    | 50        | 24.0%       |
| DSP      | 36    | 90        | 40.0%       |
| IO       | 42    | 106       | 39.6%       |

### Power Consumption (Estimated)

| Component         | Power (mW) |
|-------------------|------------|
| Clock             | 28.5       |
| Logic             | 24.7       |
| BRAM              | 15.2       |
| DSP               | 18.6       |
| IO                | 12.4       |
| **Total Dynamic** | 99.4       |
| **Static**        | 81.2       |
| **Total**         | 180.6      |

### Timing Performance

| Metric                    | Value    |
|---------------------------|----------|
| Maximum Clock Frequency   | 132 MHz  |
| Audio Processing Latency  | 18.7 ms  |
| Sample Processing Time    | 0.73 ms  |
| Detection Response Time   | 20.1 ms  |

## Real-World Performance

### Field Testing Results

| Environment      | Detection Rate | False Alarms |
|------------------|---------------|-------------|
| Quiet Room       | 98.2%         | 0.5%        |
| Office Noise     | 95.7%         | 1.8%        |
| Ambient Music    | 94.3%         | 2.4%        |
| Multiple Speakers| 92.1%         | 3.7%        |
| Distance: 1m     | 97.5%         | 1.2%        |
| Distance: 3m     | 93.4%         | 2.1%        |
| Distance: 5m     | 85.2%         | 3.8%        |

### Comparative Analysis

| System                   | Accuracy | Power  | Resources |
|--------------------------|----------|--------|-----------|
| Our FPGA Implementation  | 96.8%    | 181 mW | 16.9% LUT |
| Arm Cortex-M4 (Software) | 95.3%    | 28 mW  | N/A       |
| Custom ASIC (Est.)       | 97.2%    | 12 mW  | N/A       |
| Cloud-based Processing   | 98.5%    | N/A    | N/A       |

*Note: These metrics are based on internal testing and should be considered preliminary until validated by third-party testing.*