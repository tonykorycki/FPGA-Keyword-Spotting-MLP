`timescale 1ns / 1ps

// Testbench for I2S Receiver Module (SPH0645)
// Tests the corrected I2S timing with proper BCLK rising edge sampling

module tb_i2s_rx_working;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // I2S signals
    wire i2s_bclk;
    wire i2s_lrclk;
    reg i2s_dout;
    
    // Output signals
    wire [15:0] audio_sample;
    wire sample_valid;
    
    // Test data
    reg [17:0] test_samples [0:7];
    integer sample_index;
    integer bit_index;
    reg [17:0] current_sample;
    
    // DUT instantiation
    i2s_rx dut (
        .clk(clk),
        .rst_n(rst_n),
        .i2s_bclk(i2s_bclk),
        .i2s_lrclk(i2s_lrclk),
        .i2s_dout(i2s_dout),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid)
    );
    
    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // VCD dump
    initial begin
        $dumpfile("tb_i2s_rx_working.vcd");
        $dumpvars(0, tb_i2s_rx_working);
    end
    
    // Initialize test data (sine wave pattern at different amplitudes)
    initial begin
        test_samples[0] = 18'h00000;  // Zero
        test_samples[1] = 18'h18000;  // +0.75 * max (positive)
        test_samples[2] = 18'h1C000;  // +0.875 * max
        test_samples[3] = 18'h1E000;  // +0.9375 * max (near max)
        test_samples[4] = 18'h00000;  // Zero
        test_samples[5] = 18'h28000;  // -0.75 * max (negative)
        test_samples[6] = 18'h24000;  // -0.875 * max
        test_samples[7] = 18'h22000;  // -0.9375 * max (near min)
    end
    
    // Main test
    initial begin
        $display("===========================================");
        $display("I2S Receiver Testbench (Working Version)");
        $display("===========================================");
        
        // Initialize
        rst_n = 0;
        i2s_dout = 0;
        sample_index = 0;
        bit_index = 0;
        
        // Release reset
        #100;
        rst_n = 1;
        $display("[%0t] Reset released", $time);
        
        // Wait for first LRCLK transition
        @(posedge i2s_lrclk);
        $display("[%0t] First LRCLK high detected", $time);
        
        // Wait for LRCLK to go low (start of left channel)
        @(negedge i2s_lrclk);
        $display("[%0t] LRCLK low - starting left channel transmission", $time);
        
        // Transmit test samples
        repeat (8) begin
            current_sample = test_samples[sample_index];
            $display("[%0t] Transmitting sample #%0d: 0x%05X (%0d)", 
                     $time, sample_index, current_sample, $signed(current_sample));
            
            // Wait for BCLK to go low, then transmit on rising edge
            @(negedge i2s_lrclk);
            
            // Transmit 18 bits MSB first, then 14 zeros (32-bit frame)
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin
                @(negedge i2s_bclk);
                if (bit_index < 18) begin
                    // Send actual data bits (MSB first)
                    i2s_dout = current_sample[17 - bit_index];
                end else begin
                    // Send zeros for remaining bits
                    i2s_dout = 0;
                end
            end
            
            sample_index = sample_index + 1;
        end
        
        // Wait a bit longer to see final samples
        repeat (1000) @(posedge clk);
        
        $display("[%0t] Test complete", $time);
        $finish;
    end
    
    // Monitor received samples
    always @(posedge clk) begin
        if (sample_valid) begin
            $display("[%0t] Received sample: 0x%04X (%0d)", 
                     $time, audio_sample, $signed(audio_sample));
        end
    end

endmodule
