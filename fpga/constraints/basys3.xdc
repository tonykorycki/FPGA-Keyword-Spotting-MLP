# Constraints file for Digilent Basys 3 FPGA Board
# FPGA Keyword Spotting System
# Author: Tony Korycki
# Date: January 2026

#==============================================================================
# Clock signal (100 MHz)
#==============================================================================
set_property PACKAGE_PIN W5 [get_ports clk]							
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

#==============================================================================
# Reset button (active high - btnC, active low internally)
#==============================================================================
set_property PACKAGE_PIN U18 [get_ports btnC]						
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

#==============================================================================
# Switches (configuration)
#==============================================================================
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[7]}]
set_property PACKAGE_PIN V2 [get_ports {sw[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[8]}]
set_property PACKAGE_PIN T3 [get_ports {sw[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[9]}]
set_property PACKAGE_PIN T2 [get_ports {sw[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[10]}]
set_property PACKAGE_PIN R3 [get_ports {sw[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[11]}]
set_property PACKAGE_PIN W2 [get_ports {sw[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[12]}]
set_property PACKAGE_PIN U1 [get_ports {sw[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[13]}]
set_property PACKAGE_PIN T1 [get_ports {sw[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[14]}]
set_property PACKAGE_PIN R2 [get_ports {sw[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[15]}]

#==============================================================================
# LEDs (16 standard LEDs)
#==============================================================================
set_property PACKAGE_PIN U16 [get_ports {led[0]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]
set_property PACKAGE_PIN V13 [get_ports {led[8]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[8]}]
set_property PACKAGE_PIN V3 [get_ports {led[9]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[9]}]
set_property PACKAGE_PIN W3 [get_ports {led[10]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[10]}]
set_property PACKAGE_PIN U3 [get_ports {led[11]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[11]}]
set_property PACKAGE_PIN P3 [get_ports {led[12]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[12]}]
set_property PACKAGE_PIN N3 [get_ports {led[13]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[13]}]
set_property PACKAGE_PIN P1 [get_ports {led[14]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[14]}]
set_property PACKAGE_PIN L1 [get_ports {led[15]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[15]}]

#==============================================================================
# RGB LED16 (active low, accent LED near standard LEDs)
#==============================================================================
set_property PACKAGE_PIN N15 [get_ports led16_b]
set_property IOSTANDARD LVCMOS33 [get_ports led16_b]
set_property PACKAGE_PIN M16 [get_ports led16_g]
set_property IOSTANDARD LVCMOS33 [get_ports led16_g]
set_property PACKAGE_PIN R12 [get_ports led16_r]
set_property IOSTANDARD LVCMOS33 [get_ports led16_r]

#==============================================================================
# Pmod Header JA - I2S Microphone Interface (SPH0645)
# Directly on FPGA side (directly on JA Pmod connector)
#==============================================================================
# JA1 (Pin 1): BCLK output to mic
set_property PACKAGE_PIN J1 [get_ports i2s_bclk]					
set_property IOSTANDARD LVCMOS33 [get_ports i2s_bclk]
# JA2 (Pin 2): LRCLK (WS) output to mic  
set_property PACKAGE_PIN L2 [get_ports i2s_lrclk]					
set_property IOSTANDARD LVCMOS33 [get_ports i2s_lrclk]
# JA3 (Pin 3): Data input from mic
set_property PACKAGE_PIN J2 [get_ports i2s_dout]					
set_property IOSTANDARD LVCMOS33 [get_ports i2s_dout]

#==============================================================================
# Configuration options
#==============================================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

#==============================================================================
# Timing constraints
#==============================================================================
# All I/O is synchronous to clk, allow 1 clock cycle for I/O
set_input_delay -clock sys_clk_pin -max 3.0 [get_ports i2s_dout]
set_input_delay -clock sys_clk_pin -min 0.0 [get_ports i2s_dout]
set_output_delay -clock sys_clk_pin -max 3.0 [get_ports {i2s_bclk i2s_lrclk}]
set_output_delay -clock sys_clk_pin -min 0.0 [get_ports {i2s_bclk i2s_lrclk}]
