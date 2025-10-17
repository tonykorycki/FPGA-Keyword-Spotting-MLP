// Inference Module Testbench
// Author: 
// Date: October 17, 2025

`timescale 1ns / 1ps

module tb_inference;
    // Parameters
    localparam NUM_FEATURES = 32;
    localparam CLOCK_PERIOD = 10; // 100 MHz clock
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg [7:0] features [0:NUM_FEATURES-1];
    reg features_valid;
    wire inference_done;
    wire result;
    
    // Instantiate the inference module
    inference inference_inst (
        .clk(clk),
        .rst_n(rst_n),
        .features(features),
        .features_valid(features_valid),
        .inference_done(inference_done),
        .result(result)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize
        rst_n = 0;
        features_valid = 0;
        
        // Initialize feature data
        for (integer i = 0; i < NUM_FEATURES; i++) begin
            features[i] = 8'd0;
        end
        
        // Apply reset
        #(CLOCK_PERIOD*10);
        rst_n = 1;
        #(CLOCK_PERIOD*10);
        
        // Test Case 1: Features representing background noise
        $display("Test Case 1: Background Noise Features");
        for (integer i = 0; i < NUM_FEATURES; i++) begin
            features[i] = 8'd20 + $urandom_range(0, 10);
        end
        
        // Start inference
        features_valid = 1;
        #(CLOCK_PERIOD);
        features_valid = 0;
        
        // Wait for inference to complete
        @(posedge inference_done);
        $display("Inference Result (should be 0): %b", result);
        #(CLOCK_PERIOD*10);
        
        // Test Case 2: Features representing keyword
        $display("Test Case 2: Keyword Features");
        for (integer i = 0; i < NUM_FEATURES; i++) begin
            // Pattern more typical of the keyword
            if (i > 5 && i < 15) begin
                features[i] = 8'd180 + $urandom_range(0, 20);
            else
                features[i] = 8'd40 + $urandom_range(0, 30);
            end
        end
        
        // Start inference
        features_valid = 1;
        #(CLOCK_PERIOD);
        features_valid = 0;
        
        // Wait for inference to complete
        @(posedge inference_done);
        $display("Inference Result (should be 1): %b", result);
        #(CLOCK_PERIOD*10);
        
        // End simulation
        $finish;
    end
    
    // Monitor inference progress
    always @(posedge clk) begin
        if (inference_done) begin
            $display("Inference complete at %t ns with result: %b", $time, result);
        end
    end

endmodule