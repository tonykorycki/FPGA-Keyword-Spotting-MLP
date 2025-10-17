# ModelSim/QuestaSim simulation script for Inference module
# Author: 
# Date: October 17, 2025

# Quit any previous simulation
quit -sim

# Create work library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# Compile design files
vlog -sv ../rtl/inference.v
vlog -sv ../tb/tb_inference.v

# Start simulation
vsim -t ps work.tb_inference

# Add waves
add wave -position insertpoint sim:/tb_inference/clk
add wave -position insertpoint sim:/tb_inference/rst_n
add wave -position insertpoint sim:/tb_inference/features_valid
add wave -position insertpoint sim:/tb_inference/inference_done
add wave -position insertpoint sim:/tb_inference/result

# Add some select feature inputs
add wave -position insertpoint -radix decimal sim:/tb_inference/features(0)
add wave -position insertpoint -radix decimal sim:/tb_inference/features(1)
add wave -position insertpoint -radix decimal sim:/tb_inference/features(2)
add wave -position insertpoint -radix decimal sim:/tb_inference/features(3)

# Add internal signals from the inference module
add wave -position insertpoint sim:/tb_inference/inference_inst/state
add wave -position insertpoint -radix decimal sim:/tb_inference/inference_inst/i_counter
add wave -position insertpoint -radix decimal sim:/tb_inference/inference_inst/j_counter
add wave -position insertpoint -radix decimal sim:/tb_inference/inference_inst/acc

# Add output layer values
add wave -position insertpoint -radix decimal sim:/tb_inference/inference_inst/output_layer(0)
add wave -position insertpoint -radix decimal sim:/tb_inference/inference_inst/output_layer(1)

# Run simulation
run 100us

# Zoom to see entire simulation
wave zoom full