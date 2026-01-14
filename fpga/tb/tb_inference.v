//=============================================================================
// Testbench for Neural Network Inference Engine
//=============================================================================
// Tests the inference module against golden reference from Python
// Loads test vectors from test_input_hex.txt (quantized int8 features)
// Compares output predictions against test_output_ref.txt
//
// Author: Tony Korycki
// Date: October 31, 2025
//=============================================================================

`timescale 1ns/1ps

module tb_inference;

    //=========================================================================
    // Parameters
    //=========================================================================
    
    parameter CLK_PERIOD = 10;  // 100 MHz clock
    parameter NUM_TEST_VECTORS = 100;
    parameter NUM_FEATURES = 257;
    
    //=========================================================================
    // Signals
    //=========================================================================
    
    reg clk;
    reg rst_n;
    reg [7:0] features_array [0:256];  // Temporary array for test loading
    reg [2055:0] features_packed;      // Packed vector for DUT
    reg features_valid;
    
    wire inference_done;
    wire prediction;
    wire [63:0] logits_packed;         // Packed logits from DUT
    
    // Unpack logits for display
    wire signed [31:0] logit0 = $signed(logits_packed[31:0]);
    wire signed [31:0] logit1 = $signed(logits_packed[63:32]);
    
    // Pack features before inference
    integer pack_idx;
    always @(*) begin
        for (pack_idx = 0; pack_idx < 257; pack_idx = pack_idx + 1) begin
            features_packed[pack_idx*8 +: 8] = features_array[pack_idx];
        end
    end
    
    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    
    inference #(
        .WEIGHTS_FILE("C:/Users/koryc/fpga-kws/models/mem/weights_combined.mem"),
        .LAYER0_BIAS_FILE("C:/Users/koryc/fpga-kws/models/mem/layer0_bias.mem"),
        .LAYER1_BIAS_FILE("C:/Users/koryc/fpga-kws/models/mem/layer1_bias.mem"),
        .LAYER2_BIAS_FILE("C:/Users/koryc/fpga-kws/models/mem/layer2_bias.mem")
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .features(features_packed),
        .features_valid(features_valid),
        .inference_done(inference_done),
        .prediction(prediction),
        .logits(logits_packed)
    );
    
    //=========================================================================
    // Test Data Storage
    //=========================================================================
    
    // Input test vectors (quantized int8 features)
    reg [7:0] test_inputs [0:NUM_TEST_VECTORS-1][0:NUM_FEATURES-1];
    
    // Expected outputs (ground truth predictions)
    reg expected_outputs [0:NUM_TEST_VECTORS-1];
    
    // Results tracking
    integer num_correct;
    integer num_total;
    
    //=========================================================================
    // Clock Generation
    //=========================================================================
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //=========================================================================
    // Load Test Vectors
    //=========================================================================
    
    integer i, j;
    integer file_in, file_out, scan_result;
    reg [7:0] temp_byte;
    reg temp_pred;
    
    initial begin
        // Load input features (int8 hex values)
        file_in = $fopen("C:/Users/koryc/fpga-kws/models/test_input_hex.txt", "r");
        if (file_in == 0) begin
            $display("ERROR: Could not open test_input_hex.txt");
            $display("Run: python python/convert_test_vectors.py");
            $finish;
        end
        
        for (i = 0; i < NUM_TEST_VECTORS; i = i + 1) begin
            for (j = 0; j < NUM_FEATURES; j = j + 1) begin
                scan_result = $fscanf(file_in, "%h\n", temp_byte);
                test_inputs[i][j] = temp_byte;
            end
        end
        $fclose(file_in);
        $display("Loaded %0d test input vectors", NUM_TEST_VECTORS);
        
        // Load expected outputs (0 or 1)
        file_out = $fopen("C:/Users/koryc/fpga-kws/models/test_output_ref.txt", "r");
        if (file_out == 0) begin
            $display("ERROR: Could not open test_output_ref.txt");
            $display("Run: python python/convert_test_vectors.py");
            $finish;
        end
        
        for (i = 0; i < NUM_TEST_VECTORS; i = i + 1) begin
            scan_result = $fscanf(file_out, "%d\n", temp_pred);
            expected_outputs[i] = temp_pred;
        end
        $fclose(file_out);
        $display("Loaded %0d expected outputs", NUM_TEST_VECTORS);
    end
    
    //=========================================================================
    // Test Procedure
    //=========================================================================
    
    integer test_idx;
    integer cycle_count;
    
    initial begin
        // Initialize
        rst_n = 0;
        features_valid = 0;
        num_correct = 0;
        num_total = 0;
        
        // Apply reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("\n========================================");
        $display("Starting Inference Engine Tests");
        $display("========================================\n");
        
        // Run all test vectors
        for (test_idx = 0; test_idx < NUM_TEST_VECTORS; test_idx = test_idx + 1) begin
            
            // Load features
            for (j = 0; j < NUM_FEATURES; j = j + 1) begin
                features_array[j] = test_inputs[test_idx][j];
            end
            
            // Start inference
            @(posedge clk);
            features_valid = 1;
            @(posedge clk);
            features_valid = 0;
            
            // Wait for completion (timeout after 20,000 cycles)
            cycle_count = 0;
            while (!inference_done && cycle_count < 20000) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
            
            if (cycle_count >= 20000) begin
                $display("ERROR: Test %0d timed out!", test_idx);
                $finish;
            end
            
            // Check result
            num_total = num_total + 1;
            if (prediction == expected_outputs[test_idx]) begin
                num_correct = num_correct + 1;
                if (test_idx < 10 || (test_idx % 10 == 0)) begin
                    $display("Test %3d: PASS | Pred=%0d, Expected=%0d | Logits=[%0d, %0d] | Cycles=%0d", 
                             test_idx, prediction, expected_outputs[test_idx], 
                             logit0, logit1, cycle_count);
                end
            end else begin
                $display("Test %3d: FAIL | Pred=%0d, Expected=%0d | Logits=[%0d, %0d] | Cycles=%0d", 
                         test_idx, prediction, expected_outputs[test_idx],
                         logit0, logit1, cycle_count);
            end
            
            // Small delay between tests
            repeat(5) @(posedge clk);
        end
        
        // Print summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests:    %0d", num_total);
        $display("Passed:         %0d", num_correct);
        $display("Failed:         %0d", num_total - num_correct);
        $display("Accuracy:       %0.2f%%", (100.0 * num_correct) / num_total);
        $display("========================================\n");
        
        if (num_correct == num_total) begin
            $display("ALL TESTS PASSED!\n");
        end else begin
            $display("SOME TESTS FAILED\n");
        end
        
        $finish;
    end
    
    //=========================================================================
    // Waveform Dump (for debugging)
    //=========================================================================
    
    initial begin
        $dumpfile("inference_tb.vcd");
        $dumpvars(0, tb_inference);
    end
    
    //=========================================================================
    // Timeout Watchdog
    //=========================================================================
    
    initial begin
        #(CLK_PERIOD * 2500000);  // 25ms timeout
        $display("\nERROR: Global timeout!");
        $finish;
    end

endmodule