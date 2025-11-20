# Vivado Simulation TCL Script for Audio Pipeline Testbench
# Run this in Vivado TCL console to set up simulation

puts "=========================================="
puts "Audio Pipeline Testbench Setup"
puts "=========================================="

# Get project directory
set proj_dir [get_property DIRECTORY [current_project]]
set tb_file "$proj_dir/../../tb/tb_audio_pipeline.v"

# Check if testbench exists
if {![file exists $tb_file]} {
    puts "ERROR: Testbench file not found at: $tb_file"
    puts "Please ensure tb_audio_pipeline.v exists in fpga/tb/"
    return
}

# Add testbench to simulation sources if not already added
puts "Adding testbench to simulation sources..."
if {[catch {
    add_files -fileset sim_1 -norecurse $tb_file
} err]} {
    puts "Note: File may already be in project: $err"
}

# Set testbench as top module
puts "Setting tb_audio_pipeline as top module..."
set_property top tb_audio_pipeline [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compile order
puts "Updating compile order..."
update_compile_order -fileset sim_1

# Set simulation runtime (500ms for all tests)
set_property -name {xsim.simulate.runtime} -value {500ms} -objects [get_filesets sim_1]

puts "\nSetup complete!"
puts "To run simulation:"
puts "  1. launch_simulation"
puts "  2. run all"
puts ""
puts "Note: Waveforms will be added after simulation starts"
    # Add top-level signals
    add_wave {{/tb_audio_pipeline/clk}}
    add_wave {{/tb_audio_pipeline/rst_n}}
    add_wave {{/tb_audio_pipeline/test_num}}
    
    # I2S signals
    add_wave -divider "I2S Interface"
    add_wave {{/tb_audio_pipeline/i2s_bclk}}
    add_wave {{/tb_audio_pipeline/i2s_lrclk}}
    add_wave {{/tb_audio_pipeline/i2s_dout}}
    add_wave {{/tb_audio_pipeline/audio_sample}}
    add_wave {{/tb_audio_pipeline/sample_valid}}
    
    # Frame buffer
    add_wave -divider "Frame Buffer"
    add_wave {{/tb_audio_pipeline/frame_ready}}
    add_wave {{/tb_audio_pipeline/frame_consumed}}
    add_wave {{/tb_audio_pipeline/frames_received}}
    
    # FFT
    add_wave -divider "FFT"
    add_wave {{/tb_audio_pipeline/fft_done}}
    
    # Features
    add_wave -divider "Features"
    add_wave {{/tb_audio_pipeline/features_valid}}
    add_wave {{/tb_audio_pipeline/features_received}}
    add_wave -radix unsigned {{/tb_audio_pipeline/features[0]}}
    add_wave -radix unsigned {{/tb_audio_pipeline/features[10]}}
    add_wave -radix unsigned {{/tb_audio_pipeline/features[64]}}
    add_wave -radix unsigned {{/tb_audio_pipeline/features[128]}}
    
    # Averager (if enabled)
    if {[get_parameter ENABLE_AVERAGER] == 1} {
        add_wave -divider "Feature Averager"
        add_wave {{/tb_audio_pipeline/averaged_valid}}
        add_wave {{/tb_audio_pipeline/averaged_received}}
    }
}


