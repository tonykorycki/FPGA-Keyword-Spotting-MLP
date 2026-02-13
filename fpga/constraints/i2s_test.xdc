## I2S Microphone Test Constraints for Basys3
## Clock signal (100 MHz)
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -add [get_ports clk]

## Reset button (BTNC) - Active HIGH (pressed = 1)
set_property PACKAGE_PIN U18 [get_ports rst_btn]
set_property IOSTANDARD LVCMOS33 [get_ports rst_btn]

## I2S Microphone Pins (using PMOD JA) - FOR SPH0645
## SPH0645 is SLAVE mode - FPGA generates clocks
set_property PACKAGE_PIN J1 [get_ports i2s_bclk]
set_property PACKAGE_PIN L2 [get_ports i2s_dout]
set_property PACKAGE_PIN J2 [get_ports i2s_lrclk]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_bclk]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_dout]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_lrclk]

## LEDs for status indication
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]









create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i2s_receiver/audio_sample[0]} {i2s_receiver/audio_sample[1]} {i2s_receiver/audio_sample[2]} {i2s_receiver/audio_sample[3]} {i2s_receiver/audio_sample[4]} {i2s_receiver/audio_sample[5]} {i2s_receiver/audio_sample[6]} {i2s_receiver/audio_sample[7]} {i2s_receiver/audio_sample[8]} {i2s_receiver/audio_sample[9]} {i2s_receiver/audio_sample[10]} {i2s_receiver/audio_sample[11]} {i2s_receiver/audio_sample[12]} {i2s_receiver/audio_sample[13]} {i2s_receiver/audio_sample[14]} {i2s_receiver/audio_sample[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {audio_sample[0]} {audio_sample[1]} {audio_sample[2]} {audio_sample[3]} {audio_sample[4]} {audio_sample[5]} {audio_sample[6]} {audio_sample[7]} {audio_sample[8]} {audio_sample[9]} {audio_sample[10]} {audio_sample[11]} {audio_sample[12]} {audio_sample[13]} {audio_sample[14]} {audio_sample[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i2s_receiver/shift_reg[0]} {i2s_receiver/shift_reg[1]} {i2s_receiver/shift_reg[2]} {i2s_receiver/shift_reg[3]} {i2s_receiver/shift_reg[4]} {i2s_receiver/shift_reg[5]} {i2s_receiver/shift_reg[6]} {i2s_receiver/shift_reg[7]} {i2s_receiver/shift_reg[8]} {i2s_receiver/shift_reg[9]} {i2s_receiver/shift_reg[10]} {i2s_receiver/shift_reg[11]} {i2s_receiver/shift_reg[12]} {i2s_receiver/shift_reg[13]} {i2s_receiver/shift_reg[14]} {i2s_receiver/shift_reg[15]} {i2s_receiver/shift_reg[16]} {i2s_receiver/shift_reg[17]} {i2s_receiver/shift_reg[18]} {i2s_receiver/shift_reg[19]} {i2s_receiver/shift_reg[20]} {i2s_receiver/shift_reg[21]} {i2s_receiver/shift_reg[22]} {i2s_receiver/shift_reg[23]} {i2s_receiver/shift_reg[24]} {i2s_receiver/shift_reg[25]} {i2s_receiver/shift_reg[26]} {i2s_receiver/shift_reg[27]} {i2s_receiver/shift_reg[28]} {i2s_receiver/shift_reg[29]} {i2s_receiver/shift_reg[30]} {i2s_receiver/shift_reg[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list i2s_receiver/i2s_bclk]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list i2s_receiver/i2s_dout]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list i2s_receiver/i2s_lrclk]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list i2s_receiver/sample_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list sample_valid]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
