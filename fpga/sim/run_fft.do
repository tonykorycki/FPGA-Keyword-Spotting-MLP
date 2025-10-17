# ModelSim/QuestaSim simulation script for FFT module
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
vlog -sv ../rtl/fft_core.v
vlog -sv ../tb/tb_fft.v

# Start simulation
vsim -t ps work.tb_fft

# Add waves
add wave -position insertpoint sim:/tb_fft/clk
add wave -position insertpoint sim:/tb_fft/rst_n
add wave -position insertpoint sim:/tb_fft/start
add wave -position insertpoint sim:/tb_fft/done

# Add some select input/output waves for verification
add wave -position insertpoint -radix decimal sim:/tb_fft/x_real(0)
add wave -position insertpoint -radix decimal sim:/tb_fft/x_real(1)
add wave -position insertpoint -radix decimal sim:/tb_fft/x_real(2)
add wave -position insertpoint -radix decimal sim:/tb_fft/x_real(3)

add wave -position insertpoint -radix decimal sim:/tb_fft/y_real(0)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_real(1)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_real(2)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_real(3)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_real(4)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_real(5)

add wave -position insertpoint -radix decimal sim:/tb_fft/y_imag(0)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_imag(1)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_imag(2)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_imag(3)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_imag(4)
add wave -position insertpoint -radix decimal sim:/tb_fft/y_imag(5)

# Add internal signals from the FFT core
add wave -position insertpoint sim:/tb_fft/fft_core_inst/stage_counter
add wave -position insertpoint sim:/tb_fft/fft_core_inst/computing

# Run simulation
run 100us

# Zoom to see entire simulation
wave zoom full