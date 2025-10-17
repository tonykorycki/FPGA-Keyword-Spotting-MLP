Data folder for audio samples

Two main directories:
- `preprocessed/` - Put your raw recordings here from Audacity or other sources
  - `start/` - Raw recordings of "start" keyword
  - `silence/` - Raw recordings of silence
  - `noise/` - Raw recordings of background noise
  
- `processed/` - Standardized WAV files (16 kHz, 16-bit PCM, mono)
  - `start/` - Processed "start" keyword recordings
  - `silence/` - Processed silence recordings
  - `noise/` - Processed noise recordings

Use zero-padded filenames like `start_0001.wav`. The `python/batch_convert.py` script can convert all WAVs from preprocessed/ to processed/ automatically.

The `processed/` folder is read by the Python model training scripts in `python/`.
