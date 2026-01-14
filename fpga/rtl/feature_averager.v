//=============================================================================
// Feature Averager Module
//=============================================================================
// Implements a 1-second sliding window average over incoming feature frames
// to match the training distribution (1s averaged features).
//
// Uses a ring buffer to store the last ~31 frames (1s @ 32ms/frame, 50% overlap)
// and maintains a running sum for efficient online averaging.
//
// Author: Tony Korycki
// Date: November 18, 2025
//=============================================================================

module feature_averager #(
    parameter NUM_FEATURES = 257,      // Number of features per frame
    parameter WINDOW_FRAMES = 31,      // ~1 second @ 32ms/frame
    parameter FEATURE_WIDTH = 16,      // Bit width of each feature (signed)
    parameter SUM_WIDTH = 24           // Running sum width (must fit NUM_FEATURES * max_feature_value * WINDOW_FRAMES)
) (
    input  wire        clk,
    input  wire        rst_n,
    
    // Input: New frame of features (packed bit vector)
    input  wire [NUM_FEATURES*FEATURE_WIDTH-1:0] frame_features,  // 257*16 = 4112 bits
    input  wire                                  frame_valid,
    
    // Output: 1-second averaged features (packed bit vector)
    output reg [NUM_FEATURES*FEATURE_WIDTH-1:0] averaged_features,  // 257*16 = 4112 bits
    output reg                                  averaged_valid
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    // Unpack input features from bit vector
    wire signed [FEATURE_WIDTH-1:0] frame_features_unpacked [0:NUM_FEATURES-1];
    genvar g;
    generate
        for (g = 0; g < NUM_FEATURES; g = g + 1) begin : unpack_input
            assign frame_features_unpacked[g] = frame_features[g*FEATURE_WIDTH +: FEATURE_WIDTH];
        end
    endgenerate
    
    // Ring buffer to store last WINDOW_FRAMES frames
    reg signed [FEATURE_WIDTH-1:0] feature_buffer [0:WINDOW_FRAMES-1][0:NUM_FEATURES-1];
    
    // Running sum for each feature (wider to prevent overflow)
    reg signed [SUM_WIDTH-1:0] running_sum [0:NUM_FEATURES-1];
    
    // Internal averaged features (unpacked)
    reg signed [FEATURE_WIDTH-1:0] averaged_features_unpacked [0:NUM_FEATURES-1];
    
    // Pack output features to bit vector
    generate
        for (g = 0; g < NUM_FEATURES; g = g + 1) begin : pack_output
            always @(*) begin
                averaged_features[g*FEATURE_WIDTH +: FEATURE_WIDTH] = averaged_features_unpacked[g];
            end
        end
    endgenerate
    
    // Write pointer for ring buffer (circular)
    reg [4:0] write_ptr;  // 5 bits for up to 31 frames
    
    // Frame counter (to track warmup period)
    reg [4:0] frame_count;
    wire warmup_complete = (frame_count >= WINDOW_FRAMES);
    
    //=========================================================================
    // Sliding Window Logic
    //=========================================================================
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            write_ptr <= 5'd0;
            frame_count <= 5'd0;
            averaged_valid <= 1'b0;
            
            // Clear ring buffer and running sum
            for (i = 0; i < NUM_FEATURES; i = i + 1) begin
                running_sum[i] <= {SUM_WIDTH{1'b0}};
            end
            
        end else begin
            averaged_valid <= 1'b0;
            
            if (frame_valid) begin
                // Update ring buffer and running sum
                for (i = 0; i < NUM_FEATURES; i = i + 1) begin
                    if (warmup_complete) begin
                        // Subtract oldest frame from running sum, add new frame
                        running_sum[i] <= running_sum[i] 
                                        - feature_buffer[write_ptr][i]
                                        + frame_features_unpacked[i];
                        // Compute average from UPDATED running sum (divide by 32)
                        // Use the same expression to avoid 1-cycle timing mismatch
                        averaged_features_unpacked[i] <= (running_sum[i] 
                                        - feature_buffer[write_ptr][i]
                                        + frame_features_unpacked[i]) >>> 5;
                    end else begin
                        // Warmup phase: just accumulate, don't output yet
                        running_sum[i] <= running_sum[i] + frame_features_unpacked[i];
                        averaged_features_unpacked[i] <= 0;  // Output zeros during warmup
                    end
                    
                    // Store new frame in ring buffer
                    feature_buffer[write_ptr][i] <= frame_features_unpacked[i];
                end
                
                // Update pointers and counters
                write_ptr <= (write_ptr == WINDOW_FRAMES - 1) ? 5'd0 : write_ptr + 5'd1;
                
                if (!warmup_complete) begin
                    frame_count <= frame_count + 5'd1;
                end
                
                // Output is only valid after warmup complete (have full 1-second window)
                // This avoids false detections during startup
                averaged_valid <= warmup_complete;
            end
        end
    end

endmodule
