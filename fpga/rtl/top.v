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
    input  wire        clk,           // 50 MHz system clock (per basys3.xdc)
    input  wire        btnC,          // Center button reset

    // I2S Microphone Interface (FPGA is master, generates clocks)
    output wire        i2s_bclk,      // Bit clock to mic (~1 MHz)
    output wire        i2s_lrclk,     // LR clock to mic (~16 kHz)
    input  wire        i2s_dout,      // Data from mic

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
    (* mark_debug = "true" *) wire rst_n;

    always @(posedge clk) begin
        reset_sync <= {reset_sync[1:0], ~btnC};
    end

    assign rst_n = reset_sync[2];

    // I2S Audio Receiver
    (* mark_debug = "true" *) wire [15:0] audio_sample;
    (* mark_debug = "true" *) wire        sample_valid;

    i2s_rx i2s_receiver (
        .clk(clk),
        .rst_n(rst_n),
        .i2s_bclk(i2s_bclk),
        .i2s_lrclk(i2s_lrclk),
        .i2s_dout(i2s_dout),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid)
    );

    // Frame Buffer (serial output)
    (* mark_debug = "true" *) wire        frame_ready;
    (* mark_debug = "true" *) wire [15:0] frame_sample;
    (* mark_debug = "true" *) wire        frame_sample_valid;
    (* mark_debug = "true" *) wire        frame_consumed;

    frame_buffer fb (
        .clk(clk),
        .rst_n(rst_n),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid),
        .frame_consumed(frame_consumed),
        .fft_ready(fft_ready),
        .downstream_ready(fft_data_ready),
        .re_stream_req(re_stream_req),
        .frame_ready(frame_ready),
        .frame_sample(frame_sample),
        .frame_sample_valid(frame_sample_valid)
    );

    // FFT Core - Xilinx FFT IP Wrapper (serial input)
    (* mark_debug = "true" *) wire         fft_done;
    (* mark_debug = "true" *) wire         fft_ready;        // fft_core ready to accept a stream
    wire                               fft_data_ready;   // FFT IP backpressure (tready passthrough)
    (* mark_debug = "true" *) wire     re_stream_req;    // Recovery: fft_core missed stream
    wire [8223:0]                      fft_bins_packed;  // 257 bins x 32 bits (real+imag)
    (* mark_debug = "true" *) wire       fft_consumed;     // Handshake from feature extractor

    fft_core fft (
        .clk(clk),
        .rst_n(rst_n),
        .frame_sample(frame_sample),
        .frame_sample_valid(frame_sample_valid),
        .frame_consumed(frame_consumed),
        .fft_bins_packed(fft_bins_packed),
        .fft_done(fft_done),
        .fft_ready(fft_ready),
        .fft_data_ready(fft_data_ready),
        .re_stream_req(re_stream_req)
    );

    // Feature Extractor
    // Converts FFT spectrum to 257 INT8 features: magnitude -> log -> quantize
    (* mark_debug = "true" *) wire         features_valid_int8;
    wire [2055:0]                      features_packed_int8;  // 257 x 8 bits = 2056 bits

    feature_extractor feat_extr (
        .clk(clk),
        .rst_n(rst_n),
        .fft_bins_packed(fft_bins_packed),
        .fft_valid(fft_done),
        .fft_consumed(fft_consumed),           // Output: tells FFT "data received"
        .features_packed(features_packed_int8),
        .features_valid(features_valid_int8)
    );

    // Convert INT8 features to INT16 for averager
    // (Averager expects 16-bit inputs for accumulation headroom)
    wire [4111:0] frame_features;  // 257 x 16 bits = 4112 bits
    wire          frame_features_valid;

    assign frame_features_valid = features_valid_int8;

    genvar k;
    generate
        for (k = 0; k < 257; k = k + 1) begin : expand_features
            // Sign-extend INT8 to INT16
            assign frame_features[k*16 +: 16] = {{8{features_packed_int8[k*8+7]}}, features_packed_int8[k*8 +: 8]};
        end
    endgenerate

    // Feature Averager - 1s sliding window (matches training distribution)
    wire [4111:0] averaged_features_16bit;  // 257*16 = 4112 bits
    (* mark_debug = "true" *) wire averaged_valid;

    feature_averager #(
        .NUM_FEATURES(257),
        .WINDOW_FRAMES(31),    // ~1 second @ 32ms/frame
        .FEATURE_WIDTH(16),
        .SUM_WIDTH(24)
    ) averager (
        .clk(clk),
        .rst_n(rst_n),
        .frame_features(frame_features),
        .frame_valid(frame_features_valid),
        .averaged_features(averaged_features_16bit),
        .averaged_valid(averaged_valid)
    );

    // Convert averaged features from int16 to int8 for inference
    // Extract each 16-bit feature, saturate to int8, and pack into bit vector
    wire [2055:0] features_packed;
    genvar j;
    generate
        for (j = 0; j < 257; j = j + 1) begin : quantize_and_pack_features
            wire signed [15:0] feature_16bit;
            wire signed [7:0]  feature_8bit;

            // Extract 16-bit feature from packed vector
            assign feature_16bit = averaged_features_16bit[j*16 +: 16];

            // Saturate to int8 range [-128, 127]
            assign feature_8bit = (feature_16bit > 127) ? 8'd127 :
                                  (feature_16bit < -128) ? -8'd128 :
                                  feature_16bit[7:0];

            // Pack into output vector
            assign features_packed[j*8 +: 8] = feature_8bit;
        end
    endgenerate

    // Neural Network Inference (3-layer MLP: 257->32->16->2)
    (* mark_debug = "true" *) wire        inference_done;
    (* mark_debug = "true" *) wire        prediction;
    wire [63:0]                            logits_packed;
    wire signed [31:0]                     logits [0:1];
    (* mark_debug = "true" *) wire         detection_event;

    // Unpack logits
    assign logits[0] = logits_packed[31:0];
    assign logits[1] = logits_packed[63:32];

    inference nn_engine (
        .clk(clk),
        .rst_n(rst_n),
        .features(features_packed),
        .features_valid(averaged_valid),  // Start inference when averaged features ready
        .inference_done(inference_done),
        .prediction(prediction),
        .logits(logits_packed)
    );

    assign detection_event = inference_done & prediction;

    // Output Control
    reg [15:0] led_reg;
    reg led_detection;
    reg led_processing;
    reg led_inference;
    reg [25:0] detection_timer;
    (* mark_debug = "true" *) reg [15:0] detection_count;

    // Stretch short pipeline pulses so status is visible on physical LEDs.
    localparam [22:0] ACTIVITY_HOLD = 23'd2_500_000;  // 50ms @ 50MHz
    reg [22:0] sample_act_timer;
    reg [22:0] frame_act_timer;
    reg [22:0] fft_act_timer;
    reg [22:0] feat_act_timer;
    reg [22:0] avg_act_timer;
    reg [22:0] infer_act_timer;

    localparam HOLD_TIME = 26'd25_000_000;  // 500ms @ 50MHz

    always @(posedge clk) begin
        if (!rst_n) begin
            led_reg <= 16'h0000;
            led_detection <= 1'b0;
            led_processing <= 1'b0;
            led_inference <= 1'b0;
            detection_timer <= 26'd0;
            detection_count <= 16'd0;
            sample_act_timer <= 23'd0;
            frame_act_timer <= 23'd0;
            fft_act_timer <= 23'd0;
            feat_act_timer <= 23'd0;
            avg_act_timer <= 23'd0;
            infer_act_timer <= 23'd0;
        end else begin
            if (sample_valid) sample_act_timer <= ACTIVITY_HOLD;
            else if (sample_act_timer != 23'd0) sample_act_timer <= sample_act_timer - 23'd1;

            if (frame_ready) frame_act_timer <= ACTIVITY_HOLD;
            else if (frame_act_timer != 23'd0) frame_act_timer <= frame_act_timer - 23'd1;

            if (fft_done) fft_act_timer <= ACTIVITY_HOLD;
            else if (fft_act_timer != 23'd0) fft_act_timer <= fft_act_timer - 23'd1;

            if (frame_features_valid) feat_act_timer <= ACTIVITY_HOLD;
            else if (feat_act_timer != 23'd0) feat_act_timer <= feat_act_timer - 23'd1;

            if (averaged_valid) avg_act_timer <= ACTIVITY_HOLD;
            else if (avg_act_timer != 23'd0) avg_act_timer <= avg_act_timer - 23'd1;

            if (inference_done) infer_act_timer <= ACTIVITY_HOLD;
            else if (infer_act_timer != 23'd0) infer_act_timer <= infer_act_timer - 23'd1;

            led_reg[0] <= (sample_act_timer != 23'd0);
            led_reg[1] <= (frame_act_timer != 23'd0);
            led_reg[2] <= (fft_act_timer != 23'd0);
            led_reg[3] <= (feat_act_timer != 23'd0);
            led_reg[4] <= (avg_act_timer != 23'd0);
            led_reg[5] <= (infer_act_timer != 23'd0);
            led_reg[7] <= prediction;
            led_reg[15] <= led_detection;
            led_reg[14:8] <= detection_count[6:0];

            if (detection_event) begin
                detection_timer <= HOLD_TIME;
                led_detection <= 1'b1;
                if (detection_count != 16'hFFFF)
                    detection_count <= detection_count + 16'd1;
            end else if (detection_timer > 26'd0) begin
                detection_timer <= detection_timer - 26'd1;
            end else begin
                led_detection <= 1'b0;
            end

            led_processing <= (sample_act_timer != 23'd0) | (frame_act_timer != 23'd0) |
                              (fft_act_timer != 23'd0) | (feat_act_timer != 23'd0);
            led_inference <= (avg_act_timer != 23'd0) | (infer_act_timer != 23'd0);
        end
    end

    assign led = led_reg;
    assign led16_b = led_processing;
    assign led16_g = led_inference;
    assign led16_r = led_detection;

endmodule
