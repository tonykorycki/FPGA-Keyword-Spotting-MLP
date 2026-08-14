# Constraints file for Digilent Basys 3 FPGA Board
# FPGA Keyword Spotting System
# Author: Tony Korycki
# Date: January 2026

#==============================================================================
# Clock signal (50 MHz - reduced from 100MHz for timing closure)
#==============================================================================
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 10.000} -add [get_ports clk]

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
# RGB LED signals - Map to unused Pmod JB pins (no actual RGB LED on board)
#==============================================================================
set_property PACKAGE_PIN A14 [get_ports led16_r]
set_property IOSTANDARD LVCMOS33 [get_ports led16_r]
set_property PACKAGE_PIN A16 [get_ports led16_g]
set_property IOSTANDARD LVCMOS33 [get_ports led16_g]
set_property PACKAGE_PIN B15 [get_ports led16_b]
set_property IOSTANDARD LVCMOS33 [get_ports led16_b]

#==============================================================================
# Pmod Header JA - I2S Microphone Interface (SPH0645)
# Directly on FPGA side (directly on JA Pmod connector)
#==============================================================================
# JA1 (Pin 1): BCLK output to mic (matches fpga/constraints/i2s_test.xdc)
set_property PACKAGE_PIN J1 [get_ports i2s_bclk]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_bclk]
# JA2 (Pin 2): DOUT input from mic
set_property PACKAGE_PIN L2 [get_ports i2s_dout]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_dout]
# JA3 (Pin 3): LRCLK (WS) output to mic
set_property PACKAGE_PIN J2 [get_ports i2s_lrclk]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_lrclk]

#==============================================================================
# Configuration options
#==============================================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

#==============================================================================
# Timing constraints
#==============================================================================
# All I/O is synchronous to clk, allow 1 clock cycle for I/O
set_input_delay -clock sys_clk_pin -max 3.000 [get_ports i2s_dout]
set_input_delay -clock sys_clk_pin -min 0.000 [get_ports i2s_dout]
set_output_delay -clock sys_clk_pin -max 3.000 [get_ports {i2s_bclk i2s_lrclk}]
set_output_delay -clock sys_clk_pin -min 0.000 [get_ports {i2s_bclk i2s_lrclk}]





connect_debug_port u_ila_0/probe0 [get_nets [list {fft/state[0]} {fft/state[1]} {fft/state[2]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list {fft/sample_counter[0]} {fft/sample_counter[1]} {fft/sample_counter[2]} {fft/sample_counter[3]} {fft/sample_counter[4]} {fft/sample_counter[5]} {fft/sample_counter[6]} {fft/sample_counter[7]} {fft/sample_counter[8]} {fft/sample_counter[9]}]]
connect_debug_port u_ila_0/probe8 [get_nets [list fft/config_done]]
connect_debug_port u_ila_0/probe9 [get_nets [list fft/config_tready]]
connect_debug_port u_ila_0/probe10 [get_nets [list fft/data_in_tready]]

connect_debug_port u_ila_0/probe3 [get_nets [list {detection_count[0]} {detection_count[1]} {detection_count[2]} {detection_count[3]} {detection_count[4]} {detection_count[5]} {detection_count[6]} {detection_count[7]} {detection_count[8]} {detection_count[9]} {detection_count[10]} {detection_count[11]} {detection_count[12]} {detection_count[13]} {detection_count[14]} {detection_count[15]}]]
connect_debug_port u_ila_0/probe6 [get_nets [list detection_event]]
connect_debug_port u_ila_0/probe9 [get_nets [list fft_consumed]]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 2048 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 10 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {fb/write_ptr[0]} {fb/write_ptr[1]} {fb/write_ptr[2]} {fb/write_ptr[3]} {fb/write_ptr[4]} {fb/write_ptr[5]} {fb/write_ptr[6]} {fb/write_ptr[7]} {fb/write_ptr[8]} {fb/write_ptr[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i2s_receiver/audio_sample[0]} {i2s_receiver/audio_sample[1]} {i2s_receiver/audio_sample[2]} {i2s_receiver/audio_sample[3]} {i2s_receiver/audio_sample[4]} {i2s_receiver/audio_sample[5]} {i2s_receiver/audio_sample[6]} {i2s_receiver/audio_sample[7]} {i2s_receiver/audio_sample[8]} {i2s_receiver/audio_sample[9]} {i2s_receiver/audio_sample[10]} {i2s_receiver/audio_sample[11]} {i2s_receiver/audio_sample[12]} {i2s_receiver/audio_sample[13]} {i2s_receiver/audio_sample[14]} {i2s_receiver/audio_sample[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {fft_bin_data[0]} {fft_bin_data[1]} {fft_bin_data[2]} {fft_bin_data[3]} {fft_bin_data[4]} {fft_bin_data[5]} {fft_bin_data[6]} {fft_bin_data[7]} {fft_bin_data[8]} {fft_bin_data[9]} {fft_bin_data[10]} {fft_bin_data[11]} {fft_bin_data[12]} {fft_bin_data[13]} {fft_bin_data[14]} {fft_bin_data[15]} {fft_bin_data[16]} {fft_bin_data[17]} {fft_bin_data[18]} {fft_bin_data[19]} {fft_bin_data[20]} {fft_bin_data[21]} {fft_bin_data[22]} {fft_bin_data[23]} {fft_bin_data[24]} {fft_bin_data[25]} {fft_bin_data[26]} {fft_bin_data[27]} {fft_bin_data[28]} {fft_bin_data[29]} {fft_bin_data[30]} {fft_bin_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 64 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {logits_packed[0]} {logits_packed[1]} {logits_packed[2]} {logits_packed[3]} {logits_packed[4]} {logits_packed[5]} {logits_packed[6]} {logits_packed[7]} {logits_packed[8]} {logits_packed[9]} {logits_packed[10]} {logits_packed[11]} {logits_packed[12]} {logits_packed[13]} {logits_packed[14]} {logits_packed[15]} {logits_packed[16]} {logits_packed[17]} {logits_packed[18]} {logits_packed[19]} {logits_packed[20]} {logits_packed[21]} {logits_packed[22]} {logits_packed[23]} {logits_packed[24]} {logits_packed[25]} {logits_packed[26]} {logits_packed[27]} {logits_packed[28]} {logits_packed[29]} {logits_packed[30]} {logits_packed[31]} {logits_packed[32]} {logits_packed[33]} {logits_packed[34]} {logits_packed[35]} {logits_packed[36]} {logits_packed[37]} {logits_packed[38]} {logits_packed[39]} {logits_packed[40]} {logits_packed[41]} {logits_packed[42]} {logits_packed[43]} {logits_packed[44]} {logits_packed[45]} {logits_packed[46]} {logits_packed[47]} {logits_packed[48]} {logits_packed[49]} {logits_packed[50]} {logits_packed[51]} {logits_packed[52]} {logits_packed[53]} {logits_packed[54]} {logits_packed[55]} {logits_packed[56]} {logits_packed[57]} {logits_packed[58]} {logits_packed[59]} {logits_packed[60]} {logits_packed[61]} {logits_packed[62]} {logits_packed[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list averaged_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list features_valid_int8]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list fft_bin_last]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list fft_bin_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list fft_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list frame_consumed]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list frame_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list frame_sample_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list inference_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list prediction]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list fb/processing]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list fb/read_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list sample_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list i2s_receiver/sample_valid]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
