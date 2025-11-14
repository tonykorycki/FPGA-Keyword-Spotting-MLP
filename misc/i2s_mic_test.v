// I2S Microphone Test for SPH0645
// Simple standalone test with clear LED indicators
// Author: FPGA KWS Project
// Date: November 14, 2025
//
// LED Indicators:
// LED[0] - Heartbeat (blinks to show FPGA is running)
// LED[1] - BCLK output (should blink rapidly ~1MHz)
// LED[2] - LRCLK output (should blink slowly ~16kHz)
// LED[3] - Data input (shows raw data from mic)
// LED[4] - Sample received (pulses at 16kHz when getting samples)
// LED[5] - Audio activity (lights up when sound detected)
// LED[6] - Test in progress
// LED[7] - Test passed (solid when 1000 good samples received)

module i2s_mic_test (
    input wire clk,              // 100 MHz system clock
    input wire rst_btn,          // Center button (active high when pressed)
    
    // SPH0645 I2S Interface
    output wire i2s_bclk,        // JA1 - Bit clock to mic
    input wire i2s_dout,         // JA2 - Data from mic
    output wire i2s_lrclk,       // JA3 - LR clock to mic
    
    // Status LEDs
    output reg [7:0] led
);

    //=========================================================================
    // Reset inversion (button is active high, modules need active low)
    //=========================================================================
    wire rst_n = ~rst_btn;
    
    //=========================================================================
    // I2S Receiver Instance (generates clocks and receives data)
    //=========================================================================
    (* mark_debug = "true" *) wire [15:0] audio_sample;
    (* mark_debug = "true" *) wire sample_valid;
    
    i2s_rx i2s_receiver (
        .clk(clk),
        .rst_n(rst_n),
        .i2s_bclk(i2s_bclk),
        .i2s_lrclk(i2s_lrclk),
        .i2s_dout(i2s_dout),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid)
    );
    
    //=========================================================================
    // Audio Activity Detection & Statistics
    //=========================================================================
    reg [31:0] sample_count;
    reg [7:0] activity_level;
    reg test_passed;
    reg [15:0] non_zero_samples;
    
    // Detect if audio has meaningful signal
    wire audio_active = (audio_sample > 16'h0200) || (audio_sample < 16'hFE00);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= 32'd0;
            activity_level <= 8'd0;
            test_passed <= 1'b0;
            non_zero_samples <= 16'd0;
        end else begin
            if (sample_valid) begin
                sample_count <= sample_count + 32'd1;
                
                // Track activity
                if (audio_active) begin
                    if (activity_level < 8'd255)
                        activity_level <= activity_level + 8'd1;
                    non_zero_samples <= non_zero_samples + 16'd1;
                end else begin
                    if (activity_level > 8'd0)
                        activity_level <= activity_level - 8'd1;
                end
                
                // After 1000 samples, if we got good data, pass the test
                if (sample_count >= 32'd1000 && non_zero_samples > 16'd100) begin
                    test_passed <= 1'b1;
                end
            end
        end
    end
    
    //=========================================================================
    // LED Display
    //=========================================================================
    reg [25:0] heartbeat_counter;
    reg [15:0] bclk_activity;
    reg [15:0] lrclk_activity;
    reg bclk_prev, lrclk_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led <= 8'b00000000;
            heartbeat_counter <= 26'd0;
            bclk_activity <= 16'd0;
            lrclk_activity <= 16'd0;
            bclk_prev <= 1'b0;
            lrclk_prev <= 1'b0;
        end else begin
            heartbeat_counter <= heartbeat_counter + 26'd1;
            bclk_prev <= i2s_bclk;
            lrclk_prev <= i2s_lrclk;
            
            // Count clock toggles (decays over time)
            if (i2s_bclk != bclk_prev) begin
                bclk_activity <= 16'd50000; // Hold for visibility
            end else if (bclk_activity > 16'd0) begin
                bclk_activity <= bclk_activity - 16'd1;
            end
            
            if (i2s_lrclk != lrclk_prev) begin
                lrclk_activity <= 16'd50000; // Hold for visibility
            end else if (lrclk_activity > 16'd0) begin
                lrclk_activity <= lrclk_activity - 16'd1;
            end
            
            // LED[0] - Heartbeat (blinks every ~0.67 seconds)
            led[0] <= heartbeat_counter[25];
            
            // LED[1] - BCLK activity (stays lit while toggling)
            led[1] <= (bclk_activity > 16'd0);
            
            // LED[2] - LRCLK activity (stays lit while toggling)
            led[2] <= (lrclk_activity > 16'd0);
            
            // LED[3] - Sample count (show we're receiving samples)
            led[3] <= sample_count[10]; // Toggles as count increases
            
            // LED[4] - Sample valid pulse (stretched for visibility)
            led[4] <= sample_valid;
            
            // LED[5] - Audio activity (lights up with sound)
            led[5] <= (activity_level > 8'd50);
            
            // LED[6] - Test in progress
            led[6] <= (sample_count < 32'd1000 && sample_count > 32'd0);
            
            // LED[7] - Test passed!
            led[7] <= test_passed;
        end
    end

endmodule
