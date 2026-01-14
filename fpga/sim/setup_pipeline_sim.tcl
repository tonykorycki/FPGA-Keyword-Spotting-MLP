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

# Set simulation runtime (100ms for fast sim mode)
set_property -name {xsim.simulate.runtime} -value {100ms} -objects [get_filesets sim_1]

puts "\nSetup complete!"
puts "To run simulation:"
puts "  1. launch_simulation"
puts "  2. source add_waves.tcl (after simulation starts)"
puts "  3. run 100ms"
puts ""


