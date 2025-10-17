// KWS System Top Module
// Top-level module for the FPGA-based Keyword Spotting System
// Author: 
// Date: October 17, 2025

module top (
    input wire clk,          // System clock
    input wire rst_n,        // Active low reset
    input wire i2s_sdin,     // I2S Serial Data Input
    input wire i2s_sclk,     // I2S Serial Clock
    input wire i2s_lrclk,    // I2S Left/Right Clock
    output wire [15:0] led,  // LED outputs for visualization
    output wire detected     // Keyword detection signal
);

    // Internal signals
    wire [15:0] audio_sample;
    wire sample_valid;
    wire frame_ready;
    wire [7:0] features [0:31]; // Example: 32 features of 8-bit each
    wire inference_done;
    wire inference_result;

    // I2S Receiver
    i2s_rx i2s_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .sdin(i2s_sdin),
        .sclk(i2s_sclk),
        .lrclk(i2s_lrclk),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid)
    );

    // Frame Buffer
    frame_buffer frame_buffer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid),
        .frame_ready(frame_ready)
        // Add other necessary connections
    );

    // Feature Extractor (includes FFT)
    feature_extractor feature_extractor_inst (
        .clk(clk),
        .rst_n(rst_n),
        .frame_ready(frame_ready),
        .features(features),
        // Add other necessary connections
    );

    // Inference Engine
    inference inference_inst (
        .clk(clk),
        .rst_n(rst_n),
        .features(features),
        .inference_done(inference_done),
        .result(inference_result)
        // Add other necessary connections
    );

    // Output Control
    output_control output_control_inst (
        .clk(clk),
        .rst_n(rst_n),
        .inference_done(inference_done),
        .inference_result(inference_result),
        .led(led),
        .detected(detected)
    );

endmodule