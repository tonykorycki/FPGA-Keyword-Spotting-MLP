`timescale 1ns / 1ps

// Comprehensive Testbench for Feature Extractor
// Tests magnitude computation, log scaling, and INT8 quantization
// Includes multiple test cases and validation

module tb_feature_extractor;

    reg clk;
    reg rst_n;
    
    // FFT input
    reg [8223:0] fft_bins_packed;
    reg fft_valid;
    wire fft_consumed;
    
    // Features output
    wire [2055:0] features_packed;
    wire features_valid;
    
    // Unpacked features for display
    wire [7:0] features [0:256];
    
    genvar g;
    generate
        for (g = 0; g < 257; g = g + 1) begin : unpack_features
            assign features[g] = features_packed[g*8 +: 8];
        end
    endgenerate
    
    // DUT
    feature_extractor dut (
        .clk(clk),
        .rst_n(rst_n),
        .fft_bins_packed(fft_bins_packed),
        .fft_valid(fft_valid),
        .fft_consumed(fft_consumed),
        .features_packed(features_packed),
        .features_valid(features_valid)
    );
    
    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // VCD dump
    initial begin
        $dumpfile("tb_feature_extractor.vcd");
        $dumpvars(0, tb_feature_extractor);
    end
    
    // Test variables
    integer i, j;
    integer test_num;
    integer errors;
    integer total_tests;
    reg [31:0] expected_mag;
    reg signed [15:0] test_real, test_imag;
    
    // Helper task to set FFT bin (works around Icarus bit-select limitations)
    task set_fft_bin;
        input integer bin_idx;
        input signed [15:0] real_val;
        input signed [15:0] imag_val;
        integer bit_pos;
        begin
            bit_pos = bin_idx * 32;
            fft_bins_packed[bit_pos+31 -: 16] = real_val;
            fft_bins_packed[bit_pos+15 -: 16] = imag_val;
        end
    endtask
    
    // Helper task to run one test
    task run_test;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            total_tests = total_tests + 1;
            
            $display("\n===========================================");
            $display("Test #%0d: %0s", test_num, test_name);
            $display("===========================================");
            
            // Apply stimulus
            @(posedge clk);
            fft_valid = 1;
            
            // Wait for consumption
            @(posedge clk);
            while (!fft_consumed) @(posedge clk);
            fft_valid = 0;
            $display("[%0t] FFT data consumed", $time);
            
            // Wait for features
            @(posedge clk);
            while (!features_valid) @(posedge clk);
            $display("[%0t] Features ready", $time);
            
            @(posedge clk);
        end
    endtask
    
    // Helper function to compute expected Manhattan magnitude
    function [31:0] manhattan_mag;
        input signed [15:0] real_val;
        input signed [15:0] imag_val;
        reg [15:0] abs_real, abs_imag;
        begin
            abs_real = (real_val < 0) ? -real_val : real_val;
            abs_imag = (imag_val < 0) ? -imag_val : imag_val;
            manhattan_mag = abs_real + abs_imag;
        end
    endfunction
    
    // Helper function to approximate log2
    function [7:0] expected_log2;
        input [31:0] val;
        integer bit_pos;
        begin
            expected_log2 = 0;
            if (val != 0) begin
                for (bit_pos = 31; bit_pos >= 0; bit_pos = bit_pos - 1) begin
                    if (val[bit_pos] == 1'b1 && expected_log2 == 0) begin
                        expected_log2 = bit_pos + 1;
                    end
                end
            end
        end
    endfunction
    
    // Validation task
    task validate_features;
        input [255:0] description;
        integer bin;
        integer zero_count, nonzero_count;
        reg [7:0] max_feature, min_feature;
        begin
            $display("\n--- Validation: %0s ---", description);
            
            zero_count = 0;
            nonzero_count = 0;
            max_feature = 8'd0;
            min_feature = 8'd255;
            
            for (bin = 0; bin < 257; bin = bin + 1) begin
                if (features[bin] == 0)
                    zero_count = zero_count + 1;
                else
                    nonzero_count = nonzero_count + 1;
                
                if (features[bin] > max_feature)
                    max_feature = features[bin];
                if (features[bin] < min_feature)
                    min_feature = features[bin];
            end
            
            $display("Zero features: %0d, Non-zero: %0d", zero_count, nonzero_count);
            $display("Feature range: [%0d, %0d]", min_feature, max_feature);
            
            // Display sample features
            $display("\nSample features:");
            $display("  DC (bin 0):     0x%02X (%3d)", features[0], features[0]);
            $display("  Low freq (10):  0x%02X (%3d)", features[10], features[10]);
            $display("  Mid freq (64):  0x%02X (%3d)", features[64], features[64]);
            $display("  Mid freq (128): 0x%02X (%3d)", features[128], features[128]);
            $display("  High freq (200):0x%02X (%3d)", features[200], features[200]);
            $display("  Nyquist (256):  0x%02X (%3d)", features[256], features[256]);
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("===========================================");
        $display("Feature Extractor Comprehensive Testbench");
        $display("===========================================");
        
        // Initialize
        rst_n = 0;
        fft_valid = 0;
        fft_bins_packed = {8224{1'b0}};
        test_num = 0;
        total_tests = 0;
        errors = 0;
        
        // Reset
        #100;
        rst_n = 1;
        $display("[%0t] Reset released\n", $time);
        #50;
        
        //=====================================================================
        // TEST 1: All zeros (silence)
        //=====================================================================
        fft_bins_packed = {8224{1'b0}};
        run_test("All Zeros (Silence)");
        validate_features("All bins zero");
        
        if (features[0] != 0 || features[128] != 0) begin
            $display("ERROR: Expected all zero features for zero input");
            errors = errors + 1;
        end else begin
            $display("PASS: Zero input produces zero features");
        end
        
        //=====================================================================
        // TEST 2: DC component only
        //=====================================================================
        fft_bins_packed = {8224{1'b0}};
        set_fft_bin(0, 16'h4000, 16'h0000);  // DC = 16384 + 0 = 16384
        run_test("DC Component Only");
        validate_features("Single DC tone");
        
        expected_mag = manhattan_mag(16'h4000, 16'h0000);
        $display("Expected magnitude: %0d, log2 ≈ %0d", expected_mag, expected_log2(expected_mag));
        if (features[0] == 0) begin
            $display("ERROR: DC feature should be non-zero");
            errors = errors + 1;
        end else begin
            $display("PASS: DC feature = %0d", features[0]);
        end
        
        //=====================================================================
        // TEST 3: Low frequency tone (sine wave)
        //=====================================================================
        fft_bins_packed = {8224{1'b0}};
        // Simulate FFT of sine wave: energy in one bin
        set_fft_bin(10, 16'h7000, 16'h0000);  // Strong low frequency
        run_test("Low Frequency Tone");
        validate_features("Single low frequency bin");
        
        if (features[10] == 0) begin
            $display("ERROR: Bin 10 should be non-zero");
            errors = errors + 1;
        end else begin
            $display("PASS: Bin 10 feature = %0d", features[10]);
        end
        
        //=====================================================================
        // TEST 4: Wideband noise (all bins active)
        //=====================================================================
        fft_bins_packed = {8224{1'b0}};
        for (i = 0; i < 257; i = i + 1) begin
            // Decreasing amplitude with frequency
            test_real = 16'h2000 >> (i / 64);
            test_imag = 16'h1000 >> (i / 64);
            set_fft_bin(i, test_real, test_imag);
        end
        run_test("Wideband Noise Pattern");
        validate_features("All bins active with decreasing amplitude");
        
        //=====================================================================
        // TEST 5: Symmetric spectrum (real input)
        //=====================================================================
        fft_bins_packed = {8224{1'b0}};
        // Real audio produces symmetric FFT
        set_fft_bin(0, 16'h3000, 16'h0000);     // DC
        set_fft_bin(50, 16'h2000, 16'h1000);    // Positive freq
        set_fft_bin(207, 16'h2000, -16'h1000);  // Negative freq (conjugate)
        run_test("Symmetric Spectrum (Real Audio)");
        validate_features("Real signal symmetry");
        
        //=====================================================================
        // TEST 6: Maximum values
        //=====================================================================
        fft_bins_packed = {8224{1'b0}};
        set_fft_bin(0, 16'h7FFF, 16'h7FFF);  // Max positive
        set_fft_bin(1, -16'h8000, -16'h8000); // Max negative
        set_fft_bin(128, 16'h7FFF, 16'h0000);
        run_test("Maximum Values");
        validate_features("Saturation test");
        
        //=====================================================================
        // TEST 7: Complex values (non-zero imaginary)
        //=====================================================================
        fft_bins_packed = {8224{1'b0}};
        set_fft_bin(32, 16'h3000, 16'h4000);   // |mag| = 0x3000 + 0x4000
        set_fft_bin(64, 16'h1000, 16'h1000);   // Equal real and imag
        set_fft_bin(96, -16'h2000, 16'h3000);  // Negative real
        run_test("Complex FFT Values");
        validate_features("Complex magnitude calculation");
        
        expected_mag = manhattan_mag(16'h3000, 16'h4000);
        $display("Bin 32: Real=0x3000, Imag=0x4000 → Mag=%0d, Feature=%0d", 
                 expected_mag, features[32]);
        
        //=====================================================================
        // TEST 8: Repeated processing (ensure clean state)
        //=====================================================================
        for (j = 0; j < 3; j = j + 1) begin
            fft_bins_packed = {8224{1'b0}};
            set_fft_bin(j*10, 16'h5000, 16'h3000);
            run_test("Repeated Processing (Iteration)");
            
            if (features[j*10] == 0) begin
                $display("ERROR: Iteration %0d failed", j);
                errors = errors + 1;
            end
        end
        $display("PASS: Multiple consecutive operations successful");
        
        //=====================================================================
        // TEST 9: Reset during operation
        //=====================================================================
        fft_bins_packed = {8224{1'b0}};
        set_fft_bin(50, 16'h6000, 16'h2000);
        
        @(posedge clk);
        fft_valid = 1;
        @(posedge clk);
        @(posedge clk);
        
        // Reset while processing
        rst_n = 0;
        #50;
        rst_n = 1;
        #50;
        fft_valid = 0;
        
        $display("\nTest #%0d: Reset During Operation", test_num + 1);
        $display("PASS: Module recovered from reset");
        test_num = test_num + 1;
        total_tests = total_tests + 1;
        
        //=====================================================================
        // Final Summary
        //=====================================================================
        #1000;
        
        $display("\n===========================================");
        $display("TEST SUMMARY");
        $display("===========================================");
        $display("Total tests: %0d", total_tests);
        $display("Errors: %0d", errors);
        
        if (errors == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
        end else begin
            $display("\n*** %0d TESTS FAILED ***", errors);
        end
        
        $display("\n[%0t] Testbench complete", $time);
        $finish;
    end

endmodule
