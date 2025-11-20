# Add Waveforms for Audio Pipeline Testbench
# Run this AFTER simulation has started
# Usage: source add_waves.tcl

puts "Adding waveforms to audio pipeline testbench..."

# Add top-level signals
add_wave /tb_audio_pipeline/clk
add_wave /tb_audio_pipeline/rst_n
add_wave -radix unsigned /tb_audio_pipeline/test_num

# I2S signals
add_wave -divider "I2S Interface"
add_wave /tb_audio_pipeline/i2s_bclk
add_wave /tb_audio_pipeline/i2s_lrclk
add_wave /tb_audio_pipeline/i2s_dout
add_wave -radix hexadecimal /tb_audio_pipeline/audio_sample
add_wave /tb_audio_pipeline/sample_valid

# Frame buffer
add_wave -divider "Frame Buffer"
add_wave /tb_audio_pipeline/frame_ready
add_wave /tb_audio_pipeline/frame_consumed
add_wave -radix unsigned /tb_audio_pipeline/frames_received

# FFT
add_wave -divider "FFT"
add_wave /tb_audio_pipeline/fft_done

# Features
add_wave -divider "Features"
add_wave /tb_audio_pipeline/features_valid
add_wave /tb_audio_pipeline/fft_consumed
add_wave -radix unsigned /tb_audio_pipeline/features_received
add_wave -radix unsigned /tb_audio_pipeline/features(0)
add_wave -radix unsigned /tb_audio_pipeline/features(10)
add_wave -radix unsigned /tb_audio_pipeline/features(64)
add_wave -radix unsigned /tb_audio_pipeline/features(128)

# Averager (if enabled)
add_wave -divider "Feature Averager"
add_wave /tb_audio_pipeline/averaged_valid
add_wave -radix unsigned /tb_audio_pipeline/averaged_received

puts "Waveforms added successfully!"
puts "Run the simulation with: run all"
