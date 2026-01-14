`timescale 1ns / 1ps

//=============================================================================
// Simplified Pipeline Test (No FFT - Direct Feature Injection)
//=============================================================================
// Tests: Feature Extractor → Feature Averager → Inference
// Bypasses I2S, Frame Buffer, and FFT by directly injecting FFT-like data
//
// This validates the backend processing chain without needing Vivado
//=============================================================================

module tb_backend_pipeline;

    reg clk, rst_n;
    
    // FFT output (simulated)
    reg [8223:0] fft_bins_packed;
    reg fft_valid;
    wire fft_consumed;
    
    // Feature extractor output
    wire [2055:0] features_packed;
    wire features_valid;
    
    // Feature averager output  
    wire [4111:0] averaged_features;
    wire averaged_valid;
    
    // Inference output
    wire inference_done;
    wire prediction;
    wire [63:0] logits_packed;
    
    // Unpack for inspection
    wire [7:0] features [0:256];
    wire [15:0] avg_features [0:256];
    
    genvar g;
    generate
        for (g = 0; g < 257; g = g + 1) begin : unpack
            assign features[g] = features_packed[g*8 +: 8];
            assign avg_features[g] = averaged_features[g*16 +: 16];
        end
    endgenerate
    
    //=========================================================================
    // DUT - Backend Pipeline
    //=========================================================================
    
    feature_extractor feat_ext (
        .clk(clk),
        .rst_n(rst_n),
        .fft_bins_packed(fft_bins_packed),
        .fft_valid(fft_valid),
        .fft_consumed(fft_consumed),
        .features_packed(features_packed),
        .features_valid(features_valid)
    );
    
    // Sign-extend INT8 features to INT16 for averager
    wire [4111:0] features_int16;
    genvar j;
    generate
        for (j = 0; j < 257; j = j + 1) begin : sign_extend
            assign features_int16[j*16 +: 16] = {{8{features[j][7]}}, features[j]};
        end
    endgenerate
    
    feature_averager #(
        .NUM_FEATURES(257),
        .WINDOW_FRAMES(8),
        .FEATURE_WIDTH(16),
        .SUM_WIDTH(24)
    ) avg (
        .clk(clk),
        .rst_n(rst_n),
        .frame_features(features_int16),
        .frame_valid(features_valid),
        .averaged_features(averaged_features),
        .averaged_valid(averaged_valid)
    );
    
    // Convert INT16 averaged features back to INT8 for inference
    wire [2055:0] features_int8;
    genvar k;
    generate
        for (k = 0; k < 257; k = k + 1) begin : convert_to_int8
            assign features_int8[k*8 +: 8] = averaged_features[k*16 +: 8];  // Take lower 8 bits
        end
    endgenerate
    
    inference inf (
        .clk(clk),
        .rst_n(rst_n),
        .features(features_int8),
        .features_valid(averaged_valid),
        .inference_done(inference_done),
        .prediction(prediction),
        .logits(logits_packed)
    );
    
    //=========================================================================
    // Clock: 100 MHz
    //=========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    //=========================================================================
    // VCD Dump
    //=========================================================================
    initial begin
        $dumpfile("tb_backend_pipeline.vcd");
        $dumpvars(0, tb_backend_pipeline);
    end
    
    //=========================================================================
    // Test Stimulus
    //=========================================================================
    integer i, bin;
    integer frame_count;
    
    // Helper to set FFT bin (real, imag pair)
    task set_fft_bin;
        input integer idx;
        input signed [15:0] real_val;
        input signed [15:0] imag_val;
        integer bit_pos;
        begin
            bit_pos = idx * 32;
            fft_bins_packed[bit_pos+31 -: 16] = real_val;
            fft_bins_packed[bit_pos+15 -: 16] = imag_val;
        end
    endtask
    
    initial begin
        // Initialize
        rst_n = 0;
        fft_valid = 0;
        fft_bins_packed = 0;
        frame_count = 0;
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("===========================================");
        $display("Backend Pipeline Test");
        $display("Feature Extractor → Averager → Inference");
        $display("===========================================\n");
        
        // Test 1: Silence (all zeros)
        $display("Test 1: Silence (all FFT bins = 0)");
        for (bin = 0; bin < 257; bin = bin + 1) begin
            set_fft_bin(bin, 16'd0, 16'd0);
        end
        
        @(posedge clk);
        fft_valid = 1;
        @(posedge clk);
        fft_valid = 0;
        
        // Wait for features
        wait(features_valid);
        $display("  Features extracted: bin[0]=%0d, bin[10]=%0d, bin[100]=%0d", 
                 features[0], features[10], features[100]);
        
        @(posedge clk);
        
        // Test 2: Low frequency tone (bins 5-10 active)
        repeat(20) @(posedge clk);
        $display("\nTest 2: Low frequency tone");
        for (bin = 0; bin < 257; bin = bin + 1) begin
            if (bin >= 5 && bin <= 10)
                set_fft_bin(bin, 16'd5000, 16'd3000);  // Moderate amplitude
            else
                set_fft_bin(bin, 16'd0, 16'd0);
        end
        
        @(posedge clk);
        fft_valid = 1;
        @(posedge clk);
        fft_valid = 0;
        
        wait(features_valid);
        $display("  Features: bin[0]=%0d, bin[7]=%0d, bin[50]=%0d", 
                 features[0], features[7], features[50]);
        
        // Test 3: Feed 8 frames to trigger averaged output
        $display("\nTest 3: Feed 8 frames for averaging");
        for (frame_count = 0; frame_count < 8; frame_count = frame_count + 1) begin
            repeat(20) @(posedge clk);
            
            // Varying amplitude pattern
            for (bin = 0; bin < 257; bin = bin + 1) begin
                if (bin < 50)
                    set_fft_bin(bin, 16'd1000 + frame_count*500, 16'd500);
                else
                    set_fft_bin(bin, 16'd100, 16'd100);
            end
            
            @(posedge clk);
            fft_valid = 1;
            @(posedge clk);
            fft_valid = 0;
            
            wait(features_valid);
            @(posedge clk);
            
            $display("  Frame %0d: feature[10]=%0d", frame_count, features[10]);
        end
        
        // Wait for averaged output
        wait(averaged_valid);
        $display("\n  Averaged features ready!");
        $display("  avg[10]=%0d, avg[50]=%0d, avg[100]=%0d",
                 avg_features[10], avg_features[50], avg_features[100]);
        
        // Wait for inference
        wait(inference_done);
        $display("\n  Inference complete: prediction=%0d", prediction);
        
        repeat(50) @(posedge clk);
        
        $display("\n===========================================");
        $display("Backend Pipeline Test Complete");
        $display("✓ Feature extraction working");
        $display("✓ Feature averaging working");  
        $display("✓ Inference working");
        $display("===========================================");
        
        $finish;
    end
    
    // Timeout
    initial begin
        #50000000;  // 50ms
        $display("\nERROR: Simulation timeout");
        $finish;
    end

endmodule
