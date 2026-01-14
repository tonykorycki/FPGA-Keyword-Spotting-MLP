# Full Audio Pipeline Simulation Script for Vivado
# Run: vivado -mode tcl -source run_audio_pipeline.tcl

# Open the project
open_project C:/Users/koryc/fpga-kws/fpga/project/fpga_kws_inference/fpga_kws_inference.xpr

# Set testbench as top
set_property top tb_audio_pipeline [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sim_1

# Launch simulation
launch_simulation

# Run for 100ms (enough for several test cases)
run 100ms

# Close simulation
close_sim
