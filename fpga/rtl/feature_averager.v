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
// Modified: January 14, 2026 - Synchronous reset for BRAM inference
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
    
    // Ring buffer to store last WINDOW_FRAMES frames - flattened 1D for BRAM inference
    // Address = frame*NUM_FEATURES + feature_idx
    // 31 × 257 = 7967 entries × 16 bits = 127,472 bits total
    (* ram_style = "block" *) reg signed [FEATURE_WIDTH-1:0] feature_buffer [0:WINDOW_FRAMES*NUM_FEATURES-1];
    
    // Running sum for each feature (wider to prevent overflow)
    reg signed [SUM_WIDTH-1:0] running_sum [0:NUM_FEATURES-1];
    
    // Internal averaged features (unpacked)
    reg signed [FEATURE_WIDTH-1:0] averaged_features_unpacked [0:NUM_FEATURES-1];
    
    // Serialization index for processing features one at a time
    reg [8:0] feature_idx;  // 0 to 256
    
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
    
    // State machine for serialized processing
    localparam STATE_IDLE = 2'd0;
    localparam STATE_PROCESS = 2'd1;
    localparam STATE_DONE = 2'd2;
    
    reg [1:0] state;
    
    // Address calculation for flattened buffer
    // buffer[frame][feature] = feature_buffer[frame * NUM_FEATURES + feature]
    wire [13:0] write_addr = write_ptr * NUM_FEATURES + feature_idx;  // Up to 7967
    wire [13:0] read_addr = write_ptr * NUM_FEATURES + feature_idx;   // Same location (oldest frame)
    
    //=========================================================================
    // Sliding Window Logic - Serialized (one feature per cycle)
    //=========================================================================
    
    integer i;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset control registers only (not the RAM contents)
            write_ptr <= 5'd0;
            frame_count <= 5'd0;
            averaged_valid <= 1'b0;
            feature_idx <= 9'd0;
            state <= STATE_IDLE;
            
            // Clear running sum (this is small, ~6K bits)
            for (i = 0; i < NUM_FEATURES; i = i + 1) begin
                running_sum[i] <= {SUM_WIDTH{1'b0}};
                averaged_features_unpacked[i] <= {FEATURE_WIDTH{1'b0}};
            end
            // Note: feature_buffer is NOT reset - it gets filled during warmup
            
        end else begin
            averaged_valid <= 1'b0;
            
            case (state)
                //=============================================================
                STATE_IDLE: begin
                //=============================================================
                    if (frame_valid) begin
                        feature_idx <= 9'd0;
                        state <= STATE_PROCESS;
                    end
                end
                
                //=============================================================
                STATE_PROCESS: begin
                //=============================================================
                    // Process one feature per cycle
                    if (warmup_complete) begin
                        // Read oldest value from buffer and new input value
                        // Update running sum: subtract old, add new
                        running_sum[feature_idx] <= running_sum[feature_idx] 
                                                  - feature_buffer[read_addr] 
                                                  + frame_features_unpacked[feature_idx];
                        
                        // Compute average from updated sum (divide by 32 = shift right 5)
                        averaged_features_unpacked[feature_idx] <= 
                            (running_sum[feature_idx] - feature_buffer[read_addr] 
                             + frame_features_unpacked[feature_idx]) >>> 5;
                        
                    end else begin
                        // Warmup phase: just accumulate
                        running_sum[feature_idx] <= running_sum[feature_idx] 
                                                  + frame_features_unpacked[feature_idx];
                        averaged_features_unpacked[feature_idx] <= 16'sd0;
                    end
                    
                    // Write new value to buffer
                    feature_buffer[write_addr] <= frame_features_unpacked[feature_idx];
                    
                    // Move to next feature
                    if (feature_idx == NUM_FEATURES - 1) begin
                        state <= STATE_DONE;
                    end else begin
                        feature_idx <= feature_idx + 9'd1;
                    end
                end
                
                //=============================================================
                STATE_DONE: begin
                //=============================================================
                    // Update pointers and counters
                    write_ptr <= (write_ptr == WINDOW_FRAMES - 1) ? 5'd0 : write_ptr + 5'd1;
                    
                    if (!warmup_complete) begin
                        frame_count <= frame_count + 5'd1;
                    end
                    
                    // Output is valid after warmup complete
                    averaged_valid <= warmup_complete;
                    
                    // Return to idle
                    state <= STATE_IDLE;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
