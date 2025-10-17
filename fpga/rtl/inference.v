// Inference Module
// Neural network inference engine for keyword spotting
// Author: 
// Date: October 17, 2025

module inference (
    input wire clk,                  // System clock
    input wire rst_n,                // Active low reset
    input wire [7:0] features [0:31], // Input features (32 8-bit features)
    input wire features_valid,        // Features valid signal
    output reg inference_done,       // Inference done signal
    output reg result                // Detection result (1 = keyword detected)
);

    // Parameters
    parameter NUM_FEATURES = 32;
    parameter HIDDEN_SIZE = 64;
    parameter NUM_CLASSES = 2;  // binary classification: keyword vs. non-keyword
    
    // Memory for weights and biases (would be initialized from generated memory files)
    reg signed [7:0] layer1_weights [0:NUM_FEATURES-1][0:HIDDEN_SIZE-1];
    reg signed [7:0] layer1_bias [0:HIDDEN_SIZE-1];
    reg signed [7:0] layer2_weights [0:HIDDEN_SIZE-1][0:NUM_CLASSES-1];
    reg signed [7:0] layer2_bias [0:NUM_CLASSES-1];
    
    // Internal signals and buffers
    reg signed [15:0] hidden_layer [0:HIDDEN_SIZE-1]; // 16-bit for intermediate results
    reg signed [15:0] output_layer [0:NUM_CLASSES-1];
    
    // State machine states
    localparam IDLE = 3'd0;
    localparam LAYER1_COMPUTE = 3'd1;
    localparam LAYER1_ACTIVATE = 3'd2;
    localparam LAYER2_COMPUTE = 3'd3;
    localparam LAYER2_ACTIVATE = 3'd4;
    localparam DECIDE = 3'd5;
    localparam FINISH = 3'd6;
    
    reg [2:0] state;
    reg [7:0] i_counter, j_counter; // Counters for loops
    reg signed [31:0] acc; // Accumulator for dot products
    
    // ReLU activation function
    function signed [15:0] relu;
        input signed [15:0] x;
        begin
            relu = (x > 0) ? x : 16'd0;
        end
    endfunction
    
    // Inference process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            inference_done <= 1'b0;
            result <= 1'b0;
            i_counter <= 8'd0;
            j_counter <= 8'd0;
        end else begin
            // Default values
            inference_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (features_valid) begin
                        state <= LAYER1_COMPUTE;
                        i_counter <= 8'd0;
                        j_counter <= 8'd0;
                    end
                end
                
                LAYER1_COMPUTE: begin
                    // Compute first layer (matrix multiplication)
                    if (i_counter < HIDDEN_SIZE) begin
                        if (j_counter == 0) begin
                            // Initialize accumulator with bias
                            acc <= layer1_bias[i_counter];
                            j_counter <= j_counter + 8'd1;
                        end else if (j_counter <= NUM_FEATURES) begin
                            // Accumulate weighted sum
                            acc <= acc + features[j_counter-1] * layer1_weights[j_counter-1][i_counter];
                            j_counter <= j_counter + 8'd1;
                        end else begin
                            // Store result and move to next neuron
                            hidden_layer[i_counter] <= acc[23:8]; // Take middle 16 bits
                            i_counter <= i_counter + 8'd1;
                            j_counter <= 8'd0;
                        end
                    end else begin
                        state <= LAYER1_ACTIVATE;
                        i_counter <= 8'd0;
                    end
                end
                
                LAYER1_ACTIVATE: begin
                    // Apply ReLU activation to hidden layer
                    if (i_counter < HIDDEN_SIZE) begin
                        hidden_layer[i_counter] <= relu(hidden_layer[i_counter]);
                        i_counter <= i_counter + 8'd1;
                    end else begin
                        state <= LAYER2_COMPUTE;
                        i_counter <= 8'd0;
                        j_counter <= 8'd0;
                    end
                end
                
                LAYER2_COMPUTE: begin
                    // Compute second layer (matrix multiplication)
                    if (i_counter < NUM_CLASSES) begin
                        if (j_counter == 0) begin
                            // Initialize accumulator with bias
                            acc <= layer2_bias[i_counter];
                            j_counter <= j_counter + 8'd1;
                        end else if (j_counter <= HIDDEN_SIZE) begin
                            // Accumulate weighted sum
                            acc <= acc + hidden_layer[j_counter-1] * layer2_weights[j_counter-1][i_counter];
                            j_counter <= j_counter + 8'd1;
                        end else begin
                            // Store result and move to next output
                            output_layer[i_counter] <= acc[23:8]; // Take middle 16 bits
                            i_counter <= i_counter + 8'd1;
                            j_counter <= 8'd0;
                        end
                    end else begin
                        state <= DECIDE;
                    end
                end
                
                DECIDE: begin
                    // Make decision based on output scores
                    // For binary classification, we check if class 1 score > class 0 score
                    // Plus some threshold for better confidence
                    result <= (output_layer[1] > output_layer[0] + 16'd100) ? 1'b1 : 1'b0;
                    state <= FINISH;
                end
                
                FINISH: begin
                    inference_done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Weight initialization would happen on startup or via memory interface
    // In a real implementation, this would be done using generated memory files

endmodule