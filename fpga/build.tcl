# Build Script for FPGA-KWS Keyword Spotting System
# Run from Vivado: Tools → Run Tcl Script, or: vivado -mode tcl -source build.tcl
# Author: Tony Korycki
# Date: January 2026

set project_dir "C:/Users/koryc/fpga-kws/fpga/project/fpga_kws_inference"
set project_name "fpga_kws_inference"

puts "============================================="
puts "FPGA-KWS Build Script"
puts "============================================="

# Open existing project
puts "Opening project..."
open_project "${project_dir}/${project_name}.xpr"

# Update sources (in case RTL files changed)
puts "Updating compile order..."
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Set top module
set_property top top [current_fileset]

# Run Synthesis
puts ""
puts "============================================="
puts "Running Synthesis..."
puts "============================================="
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"

# Open synthesis results for timing report
open_run synth_1
report_utilization -file "${project_dir}/reports/post_synth_utilization.rpt"
report_timing_summary -file "${project_dir}/reports/post_synth_timing.rpt"

# Run Implementation
puts ""
puts "============================================="
puts "Running Implementation..."
puts "============================================="
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check implementation status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"

# Generate reports
open_run impl_1
report_utilization -file "${project_dir}/reports/post_impl_utilization.rpt"
report_timing_summary -file "${project_dir}/reports/post_impl_timing.rpt"
report_power -file "${project_dir}/reports/post_impl_power.rpt"

# Generate Bitstream
puts ""
puts "============================================="
puts "Generating Bitstream..."
puts "============================================="
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check bitstream generation
set bitstream_path "${project_dir}/${project_name}.runs/impl_1/top.bit"
if {[file exists $bitstream_path]} {
    puts ""
    puts "============================================="
    puts "BUILD SUCCESSFUL!"
    puts "============================================="
    puts "Bitstream: $bitstream_path"
    puts ""
    puts "To program the board:"
    puts "  1. Connect Basys3 via USB"
    puts "  2. In Vivado: Flow → Open Hardware Manager"
    puts "  3. Connect to target → Auto-connect"
    puts "  4. Program device → Select top.bit"
    puts "============================================="
} else {
    puts "ERROR: Bitstream generation failed!"
    exit 1
}

# Copy bitstream to more accessible location
file copy -force $bitstream_path "${project_dir}/../../../fpga_kws.bit"
puts "Bitstream copied to: C:/Users/koryc/fpga-kws/fpga_kws.bit"

close_project
