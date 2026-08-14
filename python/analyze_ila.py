#!/usr/bin/env python3
"""
ILA Capture Analyzer - FPGA KWS Pipeline Debug
-----------------------------------------------
Parses a Vivado ILA CSV export and replays the captured FFT spectrum through
the exact same feature extraction and INT8 inference as the RTL.

Usage:
    python analyze_ila.py <ila_capture.csv>

Steps to get the CSV from Vivado:
    1. Run ILA, trigger on fft_bin_valid rising edge
    2. In Vivado TCL console:
       write_hw_ila_data -csv -force C:/Users/koryc/fpga-kws/debug/capture.csv [get_hw_ilas hw_ila_1]
    3. Run: python python/analyze_ila.py debug/capture.csv
"""

import sys
import os
import re
import numpy as np
import matplotlib
matplotlib.use('Agg')  # headless safe; change to 'TkAgg' if you want an interactive window
import matplotlib.pyplot as plt

# ── Paths ─────────────────────────────────────────────────────────────────────
REPO_ROOT  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEM_DIR    = os.path.join(REPO_ROOT, "models", "mem")
DEBUG_DIR  = os.path.join(REPO_ROOT, "debug")

# ── Requantization scales (Q16.16) — must match inference.v parameters ────────
L0_REQUANT = 516
L1_REQUANT = 141
L2_REQUANT = 282  # used for layer 2 but final output kept as int32 logits


# ══════════════════════════════════════════════════════════════════════════════
# 1.  ILA CSV parser
# ══════════════════════════════════════════════════════════════════════════════

def _to_int(s):
    s = s.strip()
    if s.startswith("0x") or s.startswith("0X"):
        return int(s, 16)
    try:
        return int(s, 16)  # Vivado sometimes omits 0x prefix
    except ValueError:
        return int(s, 10)


def parse_ila_csv(path):
    """
    Returns a dict {column_name: np.array} for every probe column.
    Vivado CSV has a comment block at the top; data starts after the header row.
    Bus values are hex strings; single-bit values are '0'/'1'.
    """
    with open(path, "r", errors="replace") as f:
        lines = f.readlines()

    # Find header row (first non-comment line that looks like a CSV header)
    header_idx = None
    for i, line in enumerate(lines):
        if line.startswith("#") or line.strip() == "":
            continue
        # Vivado header starts with "Sample in Buffer" or similar
        header_idx = i
        break

    if header_idx is None:
        raise ValueError("Could not find header row in CSV")

    headers = [h.strip().strip('"') for h in lines[header_idx].split(",")]

    rows = []
    for line in lines[header_idx + 1:]:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip().strip('"') for p in line.split(",")]
        if len(parts) == len(headers):
            rows.append(parts)

    result = {h: [] for h in headers}
    for row in rows:
        for h, v in zip(headers, row):
            result[h].append(v)

    # Convert to arrays; try int, fall back to string
    out = {}
    for k, vals in result.items():
        try:
            out[k] = np.array([_to_int(v) for v in vals])
        except Exception:
            out[k] = np.array(vals)
    return out


def find_column(data, *candidates):
    """Case-insensitive fuzzy column lookup."""
    keys = list(data.keys())
    for candidate in candidates:
        for k in keys:
            if candidate.lower() in k.lower():
                return k
    raise KeyError(f"None of {candidates} found in columns: {keys}")


# ══════════════════════════════════════════════════════════════════════════════
# 2.  FPGA feature extraction (mirrors feature_extractor_v2.v exactly)
# ══════════════════════════════════════════════════════════════════════════════

def log2_approx_rtl(val):
    """Matches the RTL log2_approx function: 32 - leading_zeros."""
    if val <= 0:
        return 0
    return int(val).bit_length()   # bit_length() = 32 - clz for 32-bit value


def fpga_feature_extract(bin_data_array):
    """
    bin_data_array: array of uint32, each entry = fft_bin_data from ILA
    [31:16] = real (signed 16-bit), [15:0] = imag (signed 16-bit)
    Returns: np.array of 257 int8 features in [0, 127]
    """
    raw = np.array(bin_data_array, dtype=np.uint32)[:257]

    real_u = (raw >> 16) & 0xFFFF
    imag_u = raw & 0xFFFF
    real = real_u.view(np.uint16).astype(np.int16).astype(np.int32)
    imag = imag_u.view(np.uint16).astype(np.int16).astype(np.int32)

    magnitude = np.abs(real) + np.abs(imag)
    raw_log   = np.array([log2_approx_rtl(int(m)) for m in magnitude], dtype=np.int32)
    scaled    = (raw_log * 8).clip(0, 127).astype(np.int8)
    return scaled


# ══════════════════════════════════════════════════════════════════════════════
# 3.  INT8 inference from .mem files (mirrors inference.v exactly)
# ══════════════════════════════════════════════════════════════════════════════

def load_int8_mem(path):
    with open(path) as f:
        lines = [l.strip() for l in f if l.strip() and not l.startswith("//")]
    vals = np.array([int(x, 16) for x in lines], dtype=np.uint8)
    return vals.view(np.int8)


def load_int32_mem(path):
    with open(path) as f:
        lines = [l.strip() for l in f if l.strip() and not l.startswith("//")]
    vals = np.array([int(x, 16) for x in lines], dtype=np.uint32)
    return vals.view(np.int32)


def requantize(acc_int32, scale_q16):
    """clip((acc * scale) >> 16, -127, 127) — matches inference.v requantize()."""
    acc64 = acc_int32.astype(np.int64)
    return np.clip((acc64 * scale_q16) >> 16, -127, 127).astype(np.int8)


def fpga_inference(features_int8):
    """
    Replicates inference.v: 3-layer INT8 MLP (257→32→16→2).
    features_int8: shape (257,) int8 array, same format as features_packed bits.
    Returns: (prediction, logit0, logit1)
    """
    w0 = load_int8_mem(os.path.join(MEM_DIR, "layer0_weights.mem")).reshape(257, 32)
    b0 = load_int32_mem(os.path.join(MEM_DIR, "layer0_bias.mem"))
    w1 = load_int8_mem(os.path.join(MEM_DIR, "layer1_weights.mem")).reshape(32, 16)
    b1 = load_int32_mem(os.path.join(MEM_DIR, "layer1_bias.mem"))
    w2 = load_int8_mem(os.path.join(MEM_DIR, "layer2_weights.mem")).reshape(16, 2)
    b2 = load_int32_mem(os.path.join(MEM_DIR, "layer2_bias.mem"))

    x = features_int8.astype(np.int32)

    # Layer 0: 257 → 32, ReLU
    acc0 = x @ w0.astype(np.int32) + b0          # shape (32,)
    out0 = requantize(acc0, L0_REQUANT)
    out0 = np.maximum(out0, 0)                    # ReLU

    # Layer 1: 32 → 16, ReLU
    acc1 = out0.astype(np.int32) @ w1.astype(np.int32) + b1
    out1 = requantize(acc1, L1_REQUANT)
    out1 = np.maximum(out1, 0)                    # ReLU

    # Layer 2: 16 → 2, no activation (keep int32 logits)
    acc2 = out1.astype(np.int32) @ w2.astype(np.int32) + b2

    prediction = int(np.argmax(acc2))
    return prediction, int(acc2[0]), int(acc2[1])


# ══════════════════════════════════════════════════════════════════════════════
# 4.  Hardware logit extraction from ILA
# ══════════════════════════════════════════════════════════════════════════════

def extract_hw_logits(data):
    """Pull the logits_packed value captured when inference_done=1."""
    try:
        done_col   = find_column(data, "inference_done")
        logits_col = find_column(data, "logits_packed", "logits")
    except KeyError as e:
        print(f"  [warn] {e} — skipping HW logit extraction")
        return None, None

    done_rows = np.where(data[done_col] == 1)[0]
    if len(done_rows) > 0:
        raw = int(data[logits_col][done_rows[0]])
    else:
        # inference_done not in window — read the stale register value (last element)
        nonzero = np.where(data[logits_col] != 0)[0]
        if len(nonzero) == 0:
            print("  [warn] logits_packed is all-zero — inference has never run")
            return None, None
        raw = int(data[logits_col][nonzero[-1]])
    # logits: [31:0]=logit[0], [63:32]=logit[1]
    logit0 = np.int32(raw & 0xFFFFFFFF)
    logit1 = np.int32((raw >> 32) & 0xFFFFFFFF)
    return int(logit0), int(logit1)


# ══════════════════════════════════════════════════════════════════════════════
# 5.  Main analysis
# ══════════════════════════════════════════════════════════════════════════════

def analyze(csv_path):
    print(f"\n=== ILA Capture Analysis: {os.path.basename(csv_path)} ===\n")

    data = parse_ila_csv(csv_path)
    print(f"Columns found: {list(data.keys())}")
    print(f"Sample count:  {len(next(iter(data.values())))}\n")

    # ── Extract FFT bins ──────────────────────────────────────────────────────
    try:
        valid_col = find_column(data, "fft_bin_valid")
        data_col  = find_column(data, "fft_bin_data")
    except KeyError as e:
        print(f"ERROR: {e}")
        print("Make sure fft_bin_valid and fft_bin_data are in the ILA probe list.")
        return

    valid_mask = data[valid_col] == 1
    bin_data   = data[data_col][valid_mask]
    n_bins     = len(bin_data)
    print(f"FFT bins captured: {n_bins}  (expect 257)")

    if n_bins < 10:
        print("ERROR: too few bins — fft_bin_valid never asserted in capture window.")
        print("Fix: retrigger with 'fft_bin_valid = R' (rising edge) in Vivado ILA.")
        print()
        # Still extract logits if present — useful even without bin data
        hw_l0, hw_l1 = extract_hw_logits(data)
        if hw_l0 is not None:
            hw_pred = 1 if hw_l1 > hw_l0 else 0
            print(f"Hardware logits (from stale ILA value):")
            print(f"  logit[0] (no-keyword): {hw_l0:>12d}")
            print(f"  logit[1] (keyword)   : {hw_l1:>12d}")
            print(f"  prediction           : {hw_pred}")
            if abs(hw_l0) == 127 or abs(hw_l1) == 127:
                print("  *** A logit is at the INT8 clip boundary — likely requantization saturation ***")
        return

    # ── FPGA feature extraction ───────────────────────────────────────────────
    features = fpga_feature_extract(bin_data)
    print(f"\nFeature stats (257 INT8):")
    print(f"  range  : [{features.min()}, {features.max()}]")
    print(f"  mean   : {features.mean():.1f}")
    print(f"  nonzero: {(features != 0).sum()}")

    if features.max() == 0:
        print("  *** ALL ZERO — FFT output or bit-extraction is wrong ***")
    elif features.max() == 127 and features.min() == 127:
        print("  *** ALL MAX — magnitude overflow or bit-shift issue ***")

    # ── Python inference ──────────────────────────────────────────────────────
    py_pred, py_l0, py_l1 = fpga_inference(features)
    print(f"\nPython inference result:")
    print(f"  logit[0] (no-keyword): {py_l0:>12d}")
    print(f"  logit[1] (keyword)   : {py_l1:>12d}")
    print(f"  prediction           : {py_pred}  ({'keyword' if py_pred else 'no-keyword'})")

    # ── Hardware logits ───────────────────────────────────────────────────────
    hw_l0, hw_l1 = extract_hw_logits(data)
    if hw_l0 is not None:
        hw_pred = 1 if hw_l1 > hw_l0 else 0
        print(f"\nHardware logits (from ILA):")
        print(f"  logit[0] (no-keyword): {hw_l0:>12d}")
        print(f"  logit[1] (keyword)   : {hw_l1:>12d}")
        print(f"  prediction           : {hw_pred}  ({'keyword' if hw_pred else 'no-keyword'})")

        if py_pred != hw_pred:
            print("\n  *** MISMATCH: Python and hardware disagree → RTL inference bug ***")
        elif py_pred == 1:
            print("\n  Both agree: prediction=1. Likely a feature distribution mismatch")
            print("  vs training data — not an RTL bug. Compare spectrum plot to training.")
        else:
            print("\n  Both agree: prediction=0. Pipeline looks correct.")

    # ── Plot ──────────────────────────────────────────────────────────────────
    raw = np.array(bin_data[:257], dtype=np.uint32)
    real_u = ((raw >> 16) & 0xFFFF).astype(np.uint16).view(np.int16).astype(np.float32)
    imag_u = (raw & 0xFFFF).astype(np.uint16).view(np.int16).astype(np.float32)
    magnitude = np.abs(real_u) + np.abs(imag_u)

    fig, axes = plt.subplots(2, 1, figsize=(12, 7))

    axes[0].plot(magnitude)
    axes[0].set_title("FFT Magnitude (Manhattan, from hardware ILA)")
    axes[0].set_xlabel("Bin index")
    axes[0].set_ylabel("|real| + |imag|")
    axes[0].grid(True, alpha=0.3)

    axes[1].bar(range(len(features)), features.astype(np.int32), color='steelblue', width=1.0)
    axes[1].set_title(f"INT8 Features after FPGA extraction  (Python pred={py_pred})")
    axes[1].set_xlabel("Feature index (bin)")
    axes[1].set_ylabel("Feature value [0–127]")
    axes[1].set_ylim(0, 135)
    axes[1].grid(True, alpha=0.3)

    plt.tight_layout()
    os.makedirs(DEBUG_DIR, exist_ok=True)
    out_png = os.path.join(DEBUG_DIR, "ila_analysis.png")
    plt.savefig(out_png, dpi=150)
    print(f"\nPlot saved to: {out_png}")


# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python analyze_ila.py <ila_capture.csv>")
        sys.exit(1)
    analyze(sys.argv[1])
