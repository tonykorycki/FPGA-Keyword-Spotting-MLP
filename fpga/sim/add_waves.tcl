# Add Waveforms for Audio Pipeline Testbench
# Run this AFTER simulation has started
# Usage: source add_waves.tcl

puts "Adding waveforms to audio pipeline testbench..."

# Add all signals with error catching to handle missing ones gracefully
catch {add_wave /tb_audio_pipeline/clk}
catch {add_wave /tb_audio_pipeline/rst_n}
catch {add_wave -radix unsigned /tb_audio_pipeline/test_num}

# Audio interface
catch {add_wave -radix hexadecimal /tb_audio_pipeline/audio_sample}
catch {add_wave /tb_audio_pipeline/sample_valid}

# I2S signals (only in real I2S mode)
catch {add_wave /tb_audio_pipeline/i2s_bclk}
catch {add_wave /tb_audio_pipeline/i2s_lrclk}
catch {add_wave /tb_audio_pipeline/i2s_dout}

# Frame buffer
catch {add_wave /tb_audio_pipeline/frame_ready}
catch {add_wave /tb_audio_pipeline/frame_consumed}
catch {add_wave -radix unsigned /tb_audio_pipeline/frames_received}

# FFT
catch {add_wave /tb_audio_pipeline/fft_done}

# Features
catch {add_wave /tb_audio_pipeline/features_valid}
catch {add_wave /tb_audio_pipeline/fft_consumed}
catch {add_wave -radix unsigned /tb_audio_pipeline/features_received}
catch {add_wave -radix unsigned /tb_audio_pipeline/features(0)}
catch {add_wave -radix unsigned /tb_audio_pipeline/features(10)}
catch {add_wave -radix unsigned /tb_audio_pipeline/features(64)}
catch {add_wave -radix unsigned /tb_audio_pipeline/features(128)}

# Averager (if enabled)
catch {add_wave /tb_audio_pipeline/averaged_valid}
catch {add_wave -radix unsigned /tb_audio_pipeline/averaged_received}

puts "Waveforms added successfully!"
puts "Note: Some signals may not appear if not present in current configuration"
puts "Run the simulation with: run 100ms"
