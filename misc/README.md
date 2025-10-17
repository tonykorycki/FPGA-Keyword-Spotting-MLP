Misc experiments and visualization notes

Use this folder for small experiments that don't belong in the main pipeline. Example content:

- `fft_visualize.py` — quick script to compute and plot FFTs of WAV files (included).
- Notes or small testbenches for Verilog experiments. Place waveform files or small sample inputs here when you're exploring RTL behavior with recorded audio.

To visualize your recordings with the provided script, copy WAV files into `misc/` or point the script at `data/processed/<class>/` files. For example:

```
# Visualize a single processed file
python misc/fft_visualize.py data/processed/start/start_0001.wav

# Or copy a file to misc/ for quick experiments
copy data/processed/start/start_0001.wav misc/
python misc/fft_visualize.py misc/start_0001.wav
```
