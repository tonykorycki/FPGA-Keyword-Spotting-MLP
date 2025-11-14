`timescale 1ns / 1ps
//==============================================================================
// FPGA Keyword Spotting System - Top Level Module
// Target: Digilent Basys 3 (Artix-7 xc7a35tcpg236-1)
// Author: Tony Korycki
// Date: November 2025
//
// Pipeline: I2S RX -> Frame Buffer -> FFT -> Feature Extraction -> Inference
//==============================================================================

module top (
    input  wire        clk,           // 100 MHz system clock
    input  wire        btnC,          // Center button reset
    
    // I2S Microphone Interface (TODO)
    input  wire        i2s_sclk,
    input  wire        i2s_lrclk, //left right channel select
    input  wire        i2s_sdin,
    
    // Status outputs
    output wire [15:0] led,
    output wire        led16_b,       // Blue: processing
    output wire        led16_g,       // Green: inference
    output wire        led16_r,       // Red: detection 
    
    // Configuration
    input  wire [15:0] sw
);

    // Parameters
    localparam SAMPLE_RATE  = 16000;
    localparam FRAME_SIZE   = 512;
    localparam NUM_FEATURES = 257;
    
    // Reset synchronization
    reg [2:0] reset_sync;
    wire rst_n;
    
    always @(posedge clk) begin
        reset_sync <= {reset_sync[1:0], ~btnC};
    end
    
    assign rst_n = reset_sync[2];
    
    // I2S Audio Receiver (TODO)
    wire [15:0] audio_sample;
    wire        sample_valid;
    
    assign audio_sample = 16'h0000;
    assign sample_valid = 1'b0;
    
    // Frame Buffer (TODO)
    wire                frame_ready;
    wire signed [15:0]  frame_data [0:511];
    wire                frame_consumed;
    
    assign frame_ready = 1'b0;
    
    // FFT Core (TODO - Xilinx FFT IP)
    wire                fft_start;
    wire                fft_done;
    wire signed [15:0]  fft_real [0:256];
    wire signed [15:0]  fft_imag [0:256];
    
    assign fft_done = 1'b0;
    
    // Feature Extractor (TODO)
    // Converts FFT spectrum to 257 INT8 features: magnitude -> log -> quantize
    wire                features_valid;
    wire signed [7:0]   features [0:256];
    
    assign features_valid = 1'b0;
    
    // Neural Network Inference (3-layer MLP: 257->32->16->2)
    wire                inference_start;
    wire                inference_done;
    wire                prediction;
    wire signed [31:0]  logits [0:1];
    
    assign inference_start = sw[15]; //for testing rn start inference when switch 15 is high
    
    inference nn_engine (
        .clk(clk),
        .rst_n(rst_n),
        .inference_start(inference_start),
        .features(features),
        .inference_done(inference_done),
        .prediction(prediction),
        .logits(logits)
    );
    
    // Output Control
    reg [15:0] led_reg;
    reg led_detection;
    reg led_processing;
    reg led_inference;
    reg [25:0] detection_timer;
    localparam HOLD_TIME = 26'd50_000_000;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_reg <= 16'h0000;
            led_detection <= 1'b0;
            led_processing <= 1'b0;
            led_inference <= 1'b0;
            detection_timer <= 26'd0;
        end else begin
            led_reg[0]  <= sample_valid;
            led_reg[1]  <= frame_ready;
            led_reg[2]  <= fft_done;
            led_reg[3]  <= features_valid;
            led_reg[4]  <= inference_start;
            led_reg[5]  <= inference_done;
            led_reg[6]  <= prediction;
            led_reg[15] <= led_detection;
            led_reg[14:7] <= sw[14:7];
            
            if (inference_done && prediction) begin
                detection_timer <= HOLD_TIME; //turn on LED for 500ms
                led_detection <= 1'b1;
            end else if (detection_timer > 0) begin
                detection_timer <= detection_timer - 1;
            end else begin
                led_detection <= 1'b0;
            end
            
            led_processing <= frame_ready | fft_done | features_valid;
            led_inference  <= inference_start;
        end
    end
    
    assign led = led_reg;
    assign led16_b = led_processing;
    assign led16_g = led_inference;
    assign led16_r = led_detection;
    
endmodule