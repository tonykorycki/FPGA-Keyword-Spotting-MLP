//=============================================================================
// Neural Network Inference Engine
//=============================================================================
// 3-layer quantized neural network for keyword spotting
// Architecture:
//   Layer 0: 257 inputs -> 32 outputs (Dense + ReLU)
//   Layer 1: 32 inputs  -> 16 outputs (Dense + ReLU)
//   Layer 2: 16 inputs  -> 2 outputs  (Dense, no activation)
//   Output:  argmax(logits) -> prediction (0 or 1)
//
// Quantization: int8 weights, int32 accumulator, int8 activations
// Sequential MAC architecture (1 multiply-add per cycle)
//
// Author: Tony Korycki
// Date: October 31, 2025
//=============================================================================

module inference #(
    // Layer dimensions
    parameter L0_IN = 257,
    parameter L0_OUT = 32,
    parameter L1_IN = 32,
    parameter L1_OUT = 16,
    parameter L2_IN = 16,
    parameter L2_OUT = 2,
    
    // Requantization scale factors (Q16.16 fixed-point)
    // These values are from scales.json: requantize_scale * 2^16
    parameter signed [31:0] L0_REQUANT_SCALE = 32'd516,   // 0.007874015718698502 * 65536
    parameter signed [31:0] L1_REQUANT_SCALE = 32'd141,   // 0.002151927910745144 * 65536
    parameter signed [31:0] L2_REQUANT_SCALE = 32'd282,   // 0.004303930327296257 * 65536
    
    // Memory file paths
    parameter LAYER0_WEIGHTS_FILE = "../../models/mem/layer0_weights.mem",
    parameter LAYER0_BIAS_FILE    = "../../models/mem/layer0_bias.mem",
    parameter LAYER1_WEIGHTS_FILE = "../../models/mem/layer1_weights.mem",
    parameter LAYER1_BIAS_FILE    = "../../models/mem/layer1_bias.mem",
    parameter LAYER2_WEIGHTS_FILE = "../../models/mem/layer2_weights.mem",
    parameter LAYER2_BIAS_FILE    = "../../models/mem/layer2_bias.mem"
) (
    input  wire        clk,                    // System clock
    input  wire        rst_n,                  // Active-low reset
    
    // Input interface
    input  wire [7:0]  features [0:256],       // 257 int8 input features
    input  wire        features_valid,         // Start inference
    
    // Output interface
    output reg         inference_done,         // Inference complete (1 cycle pulse)
    output reg         prediction,             // Classification result (0 or 1)
    output reg  [31:0] logits [0:1]            // Raw output scores (for debugging)
);

    //=========================================================================
    // Weight and Bias Memory
    //=========================================================================
    
    // Layer 0: 257 x 32 = 8,224 weights
    reg [7:0] layer0_weights [0:8223];
    reg signed [31:0] layer0_bias [0:31];
    
    // Layer 1: 32 x 16 = 512 weights
    reg [7:0] layer1_weights [0:511];
    reg signed [31:0] layer1_bias [0:15];
    
    // Layer 2: 16 x 2 = 32 weights
    reg [7:0] layer2_weights [0:31];
    reg signed [31:0] layer2_bias [0:1];
    
    // Load weights and biases from memory files
    initial begin
        $readmemh(LAYER0_WEIGHTS_FILE, layer0_weights);
        $readmemh(LAYER0_BIAS_FILE, layer0_bias);
        $readmemh(LAYER1_WEIGHTS_FILE, layer1_weights);
        $readmemh(LAYER1_BIAS_FILE, layer1_bias);
        $readmemh(LAYER2_WEIGHTS_FILE, layer2_weights);
        $readmemh(LAYER2_BIAS_FILE, layer2_bias);
    end
    
    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    // Input feature buffer (copy of inputs)
    reg signed [7:0] input_buffer [0:256];
    
    // Layer outputs
    reg signed [7:0] layer0_output [0:31];
    reg signed [7:0] layer1_output [0:15];
    reg signed [7:0] layer2_output [0:1];  // Final layer output (logits, int8)
    
    // MAC unit signals
    reg signed [7:0]  mac_weight;
    reg signed [7:0]  mac_activation;
    reg signed [31:0] mac_accumulator;
    wire signed [15:0] mac_product;
    
    // Multiply (combinational)
    assign mac_product = mac_weight * mac_activation;
    
    // State machine
    localparam STATE_IDLE        = 4'd0;
    localparam STATE_LOAD_INPUT  = 4'd1;
    localparam STATE_L0_MAC      = 4'd2;
    localparam STATE_L0_REQUANT  = 4'd3;
    localparam STATE_L1_MAC      = 4'd4;
    localparam STATE_L1_REQUANT  = 4'd5;
    localparam STATE_L2_MAC      = 4'd6;
    localparam STATE_L2_REQUANT  = 4'd7;
    localparam STATE_ARGMAX      = 4'd8;
    localparam STATE_DONE        = 4'd9;
    
    reg [3:0] state;
    
    // Loop counters
    reg [8:0] input_idx;      // 0 to 256 (9 bits)
    reg [5:0] output_idx;     // 0 to 31 (6 bits)
    reg [13:0] weight_addr;   // Weight memory address (up to 8224)
    reg first_mac;            // Flag for first MAC cycle (skip accumulation)
    
    //=========================================================================
    // Requantization Function
    //=========================================================================
    // Converts int32 accumulator to int8 with scaling
    // Formula: output = clip((acc * requant_scale) >> 16, -127, 127)
    
    function signed [7:0] requantize;
        input signed [31:0] accumulator;
        input signed [31:0] scale;
        reg signed [63:0] scaled;
        reg signed [31:0] shifted;
        begin
            // Multiply by fixed-point scale (Q16.16)
            scaled = accumulator * scale;
            
            // Shift right by 16 to get back to integer
            shifted = scaled >>> 16;
            
            // Clip to int8 range [-127, 127]
            if (shifted > 127)
                requantize = 8'd127;
            else if (shifted < -127)
                requantize = -8'd127;
            else
                requantize = shifted[7:0];
        end
    endfunction
    
    //=========================================================================
    // ReLU Activation
    //=========================================================================
    
    function signed [7:0] relu;
        input signed [7:0] x;
        begin
            relu = (x > 0) ? x : 8'd0;
        end
    endfunction
    
    //=========================================================================
    // Main State Machine
    //=========================================================================
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            inference_done <= 1'b0;
            prediction <= 1'b0;
            input_idx <= 9'd0;
            output_idx <= 6'd0;
            weight_addr <= 14'd0;
            mac_accumulator <= 32'd0;
            mac_weight <= 8'd0;
            mac_activation <= 8'd0;
            first_mac <= 1'b0;
            
            // Clear outputs
            for (i = 0; i < 2; i = i + 1) begin
                logits[i] <= 32'd0;
            end
            
        end else begin
            // Default values
            inference_done <= 1'b0;
            
            case (state)
                //-------------------------------------------------------------
                // IDLE: Wait for input features
                //-------------------------------------------------------------
                STATE_IDLE: begin
                    if (features_valid) begin
                        state <= STATE_LOAD_INPUT;
                        input_idx <= 9'd0;
                    end
                end
                
                //-------------------------------------------------------------
                // LOAD_INPUT: Copy input features to buffer
                //-------------------------------------------------------------
                STATE_LOAD_INPUT: begin
                    input_buffer[input_idx] <= $signed(features[input_idx]);
                    
                    if (input_idx == L0_IN - 1) begin
                        // All inputs loaded, start Layer 0
                        state <= STATE_L0_MAC;
                        output_idx <= 6'd0;
                        input_idx <= 9'd0;
                        weight_addr <= 14'd0;
                        mac_accumulator <= layer0_bias[0];  // Initialize with bias
                        first_mac <= 1'b1;  // First MAC cycle - don't accumulate yet
                    end else begin
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 0: MAC (257 inputs x 32 outputs = 8,224 operations)
                //-------------------------------------------------------------
                STATE_L0_MAC: begin
                    // Load weight and activation
                    mac_weight <= $signed(layer0_weights[weight_addr]);
                    mac_activation <= input_buffer[input_idx];
                    
                    // Accumulate (skip first cycle - product not ready yet)
                    if (!first_mac) begin
                        mac_accumulator <= mac_accumulator + $signed(mac_product);
                    end else begin
                        first_mac <= 1'b0;  // Clear flag after first cycle
                    end
                    
                    // Advance to next weight/input
                    if (input_idx == L0_IN - 1) begin
                        // Completed one output neuron - need one more cycle for last product
                        state <= STATE_L0_REQUANT;
                    end else begin
                        input_idx <= input_idx + 9'd1;
                        weight_addr <= weight_addr + L0_OUT;  // Weights stored row-major: stride by num_outputs
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 0: Requantize and apply ReLU
                //-------------------------------------------------------------
                STATE_L0_REQUANT: begin
                    // Requantize accumulator to int8 (add final product before requantization)
                    layer0_output[output_idx] <= relu(requantize(mac_accumulator + $signed(mac_product), L0_REQUANT_SCALE));
                    
                    if (output_idx == L0_OUT - 1) begin
                        // All Layer 0 outputs computed, start Layer 1
                        state <= STATE_L1_MAC;
                        output_idx <= 6'd0;
                        input_idx <= 9'd0;
                        weight_addr <= 14'd0;
                        mac_accumulator <= layer1_bias[0];
                        first_mac <= 1'b1;
                    end else begin
                        // Move to next output neuron
                        output_idx <= output_idx + 6'd1;
                        input_idx <= 9'd0;
                        weight_addr <= output_idx + 6'd1;  // Start at weight[0, output_idx+1]
                        mac_accumulator <= layer0_bias[output_idx + 1];
                        first_mac <= 1'b1;
                        state <= STATE_L0_MAC;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 1: MAC (32 inputs x 16 outputs = 512 operations)
                //-------------------------------------------------------------
                STATE_L1_MAC: begin
                    mac_weight <= $signed(layer1_weights[weight_addr]);
                    mac_activation <= layer0_output[input_idx];
                    
                    if (!first_mac) begin
                        mac_accumulator <= mac_accumulator + $signed(mac_product);
                    end else begin
                        first_mac <= 1'b0;
                    end
                    
                    if (input_idx == L1_IN - 1) begin
                        state <= STATE_L1_REQUANT;
                    end else begin
                        input_idx <= input_idx + 9'd1;
                        weight_addr <= weight_addr + L1_OUT;  // Stride by num_outputs
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 1: Requantize and apply ReLU
                //-------------------------------------------------------------
                STATE_L1_REQUANT: begin
                    layer1_output[output_idx] <= relu(requantize(mac_accumulator + $signed(mac_product), L1_REQUANT_SCALE));
                    
                    if (output_idx == L1_OUT - 1) begin
                        state <= STATE_L2_MAC;
                        output_idx <= 6'd0;
                        input_idx <= 9'd0;
                        weight_addr <= 14'd0;
                        mac_accumulator <= layer2_bias[0];
                        first_mac <= 1'b1;
                    end else begin
                        output_idx <= output_idx + 6'd1;
                        input_idx <= 9'd0;
                        weight_addr <= output_idx + 6'd1;  // Start at weight[0, output_idx+1]
                        mac_accumulator <= layer1_bias[output_idx + 1];
                        first_mac <= 1'b1;
                        state <= STATE_L1_MAC;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 2: MAC (16 inputs x 2 outputs = 32 operations)
                //-------------------------------------------------------------
                STATE_L2_MAC: begin
                    mac_weight <= $signed(layer2_weights[weight_addr]);
                    mac_activation <= layer1_output[input_idx];
                    
                    if (!first_mac) begin
                        mac_accumulator <= mac_accumulator + $signed(mac_product);
                    end else begin
                        first_mac <= 1'b0;
                    end
                    
                    if (input_idx == L2_IN - 1) begin
                        // Done with this neuron's MAC operations
                        state <= STATE_L2_REQUANT;
                    end else begin
                        input_idx <= input_idx + 9'd1;
                        weight_addr <= weight_addr + L2_OUT;  // Stride by num_outputs
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 2: Requantize and store (no ReLU on final layer)
                //-------------------------------------------------------------
                STATE_L2_REQUANT: begin
                    // Requantize and clip to int8 (no ReLU on logits)
                    layer2_output[output_idx] <= requantize(mac_accumulator + $signed(mac_product), L2_REQUANT_SCALE);
                    
                    if (output_idx == L2_OUT - 1) begin
                        state <= STATE_ARGMAX;
                    end else begin
                        output_idx <= output_idx + 6'd1;
                        input_idx <= 9'd0;
                        weight_addr <= output_idx + 6'd1;  // Start at weight[0, output_idx+1]
                        mac_accumulator <= layer2_bias[output_idx + 1];
                        first_mac <= 1'b1;
                        state <= STATE_L2_MAC;
                    end
                end
                
                //-------------------------------------------------------------
                // ARGMAX: Compare logits and make prediction
                //-------------------------------------------------------------
                STATE_ARGMAX: begin
                    logits[0] <= layer2_output[0];
                    logits[1] <= layer2_output[1];
                    
                    // Prediction = argmax(logit[0], logit[1])
                    prediction <= (layer2_output[1] > layer2_output[0]) ? 1'b1 : 1'b0;
                    
                    state <= STATE_DONE;
                end
                
                //-------------------------------------------------------------
                // DONE: Pulse inference_done and return to IDLE
                //-------------------------------------------------------------
                STATE_DONE: begin
                    inference_done <= 1'b1;
                    state <= STATE_IDLE;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule