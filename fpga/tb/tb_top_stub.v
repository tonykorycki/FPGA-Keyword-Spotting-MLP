// Top Module Testbench with Stub Components
// Author: 
// Date: October 17, 2025

`timescale 1ns / 1ps

module tb_top_stub;
    // Parameters
    localparam CLOCK_PERIOD = 10; // 100 MHz clock
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg i2s_sdin;
    reg i2s_sclk;
    reg i2s_lrclk;
    wire [15:0] led;
    wire detected;
    
    // Instantiate the top module
    top top_inst (
        .clk(clk),
        .rst_n(rst_n),
        .i2s_sdin(i2s_sdin),
        .i2s_sclk(i2s_sclk),
        .i2s_lrclk(i2s_lrclk),
        .led(led),
        .detected(detected)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    // I2S clock generation (slower than system clock)
    initial begin
        i2s_sclk = 0;
        forever #(CLOCK_PERIOD*5) i2s_sclk = ~i2s_sclk; // 10 MHz
    end
    
    // I2S left/right clock (frame clock)
    initial begin
        i2s_lrclk = 0;
        forever #(CLOCK_PERIOD*160) i2s_lrclk = ~i2s_lrclk; // ~312.5 kHz
    end
    
    // Test stimulus
    initial begin
        // Initialize
        rst_n = 0;
        i2s_sdin = 0;
        
        // Apply reset
        #(CLOCK_PERIOD*10);
        rst_n = 1;
        #(CLOCK_PERIOD*10);
        
        // Simulate sending audio data over I2S
        // In a real test, this would be a sine wave or recorded audio
        for (integer i = 0; i < 1000; i++) begin
            // For simplicity, toggle the data line based on counter
            // In a real test, this would be actual audio data
            i2s_sdin = (i % 7 == 0);
            #(CLOCK_PERIOD*10);
        end
        
        // Simulate some more time to allow processing
        #(CLOCK_PERIOD*10000);
        
        // End simulation
        $finish;
    end
    
    // Monitor detection signal
    always @(posedge detected) begin
        $display("Keyword detected at %t ns", $time);
    end
    
    // Monitor LED changes
    reg [15:0] prev_led = 0;
    always @(posedge clk) begin
        if (led !== prev_led) begin
            $display("LED state changed to %h at %t ns", led, $time);
            prev_led = led;
        end
    end

endmodule