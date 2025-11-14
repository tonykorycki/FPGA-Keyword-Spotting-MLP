// Testbench for I2S Receiver Module
// This testbench simulates an I2S microphone sending audio data
// Author: Test for FPGA KWS project
// Date: November 13, 2025

`timescale 1ns / 1ps

module tb_i2s_rx;

    // Testbench signals
    reg clk;
    reg rst_n;
    reg sdin;
    reg sclk;
    reg lrclk;
    wire [15:0] audio_sample;
    wire sample_valid;

    // Instantiate the I2S receiver
    i2s_rx uut (
        .clk(clk),
        .rst_n(rst_n),
        .sdin(sdin),
        .sclk(sclk),
        .lrclk(lrclk),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid)
    );

    // Clock generation (50 MHz system clock)
    initial clk = 0;
    always #10 clk = ~clk;  // 50 MHz clock (20ns period)

    // Test variables
    integer i, j;
    reg [15:0] test_samples [0:7];
    integer sample_count;
    
    // I2S timing parameters
    // For 16kHz sample rate with 16-bit samples:
    // BCLK (sclk) = 16kHz * 2 channels * 16 bits = 512 kHz
    // LRCLK = 16 kHz
    parameter SCLK_PERIOD = 1953;  // ns (512 kHz)
    parameter LRCLK_PERIOD = SCLK_PERIOD * 32;  // 16 bits per channel * 2 channels

    // Task to send one I2S sample (16 bits)
    task send_i2s_sample;
        input [15:0] sample_data;
        integer bit_idx;
        begin
            for (bit_idx = 15; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                // Setup data on falling edge of SCLK
                #(SCLK_PERIOD/2) sclk = 1'b0;
                sdin = sample_data[bit_idx];
                // Data is sampled on rising edge of SCLK
                #(SCLK_PERIOD/2) sclk = 1'b1;
            end
        end
    endtask

    // Task to send a complete I2S frame (left + right channels)
    task send_i2s_frame;
        input [15:0] left_sample;
        input [15:0] right_sample;
        begin
            // Left channel (LRCLK = 0)
            lrclk = 1'b0;
            send_i2s_sample(left_sample);
            
            // Right channel (LRCLK = 1)
            lrclk = 1'b1;
            send_i2s_sample(right_sample);
        end
    endtask

    // Main test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        sdin = 0;
        sclk = 0;
        lrclk = 0;
        sample_count = 0;

        // Create test pattern samples
        test_samples[0] = 16'h0000;  // Silence
        test_samples[1] = 16'h1000;  // Low amplitude positive
        test_samples[2] = 16'h4000;  // Medium amplitude positive
        test_samples[3] = 16'h7FFF;  // Maximum positive
        test_samples[4] = 16'hF000;  // Low amplitude negative
        test_samples[5] = 16'hC000;  // Medium amplitude negative
        test_samples[6] = 16'h8000;  // Maximum negative
        test_samples[7] = 16'hAAAA;  // Alternating pattern

        // Open VCD file for waveform viewing
        $dumpfile("tb_i2s_rx.vcd");
        $dumpvars(0, tb_i2s_rx);

        // Display test header
        $display("===================================");
        $display("I2S Receiver Testbench");
        $display("===================================");
        $display("Time\t\tSample\t\tValid\tExpected");
        $display("-----------------------------------");

        // Hold reset for a few clock cycles
        #100;
        rst_n = 1;
        #100;

        // Test 1: Send known test patterns
        $display("\n--- Test 1: Known Test Patterns ---");
        for (i = 0; i < 8; i = i + 1) begin
            send_i2s_frame(test_samples[i], test_samples[i]);
            #100;  // Wait a bit between samples
        end

        // Test 2: Send a sine wave pattern (simplified)
        $display("\n--- Test 2: Sine Wave Pattern ---");
        for (i = 0; i < 16; i = i + 1) begin
            // Simple sine approximation using case statement
            case (i % 16)
                0:  send_i2s_frame(16'h0000, 16'h0000);
                1:  send_i2s_frame(16'h30FB, 16'h30FB);
                2:  send_i2s_frame(16'h5A82, 16'h5A82);
                3:  send_i2s_frame(16'h7641, 16'h7641);
                4:  send_i2s_frame(16'h7FFF, 16'h7FFF);
                5:  send_i2s_frame(16'h7641, 16'h7641);
                6:  send_i2s_frame(16'h5A82, 16'h5A82);
                7:  send_i2s_frame(16'h30FB, 16'h30FB);
                8:  send_i2s_frame(16'h0000, 16'h0000);
                9:  send_i2s_frame(16'hCF05, 16'hCF05);
                10: send_i2s_frame(16'hA57E, 16'hA57E);
                11: send_i2s_frame(16'h89BF, 16'h89BF);
                12: send_i2s_frame(16'h8000, 16'h8000);
                13: send_i2s_frame(16'h89BF, 16'h89BF);
                14: send_i2s_frame(16'hA57E, 16'hA57E);
                15: send_i2s_frame(16'hCF05, 16'hCF05);
            endcase
            #100;
        end

        // Test 3: Continuous stream
        $display("\n--- Test 3: Continuous Stream ---");
        for (i = 0; i < 32; i = i + 1) begin
            send_i2s_frame($random, $random);
            #50;
        end

        // Summary
        $display("\n===================================");
        $display("Test Complete!");
        $display("Total samples received: %0d", sample_count);
        $display("===================================");

        #1000;
        $finish;
    end

    // Monitor for debugging
    always @(posedge sample_valid) begin
        sample_count = sample_count + 1;
        $display("%0t: Received sample: %h (%d decimal)", 
                 $time, audio_sample, $signed(audio_sample));
    end

    // Timeout watchdog
    initial begin
        #100000000;  // 100ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
