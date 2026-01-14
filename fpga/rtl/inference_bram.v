//=============================================================================
// Neural Network Inference Engine - BRAM Optimized Version
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
// BRAM Optimization:
//   - All weights stored in single BRAM (8,768 x 8-bit)
//   - Pipelined reads to handle 1-cycle BRAM latency
//   - Biases remain in distributed RAM (only 50 values)
//
// Address layout in unified weight BRAM:
//   0-8223:     layer0_weights (257×32)
//   8224-8735:  layer1_weights (32×16)
//   8736-8767:  layer2_weights (16×2)
//
// Author: Tony Korycki
// Date: October 31, 2025
// Modified: January 14, 2026 - BRAM rewrite for synthesis
//=============================================================================

module inference #(
    // Layer dimensions
    parameter L0_IN = 257,
    parameter L0_OUT = 32,
    parameter L1_IN = 32,
    parameter L1_OUT = 16,
    parameter L2_IN = 16,
    parameter L2_OUT = 2,
    
    // Weight counts per layer
    parameter L0_WEIGHTS = L0_IN * L0_OUT,  // 8224
    parameter L1_WEIGHTS = L1_IN * L1_OUT,  // 512
    parameter L2_WEIGHTS = L2_IN * L2_OUT,  // 32
    parameter TOTAL_WEIGHTS = L0_WEIGHTS + L1_WEIGHTS + L2_WEIGHTS,  // 8768
    
    // BRAM address offsets
    parameter L0_WEIGHT_BASE = 0,
    parameter L1_WEIGHT_BASE = L0_WEIGHTS,           // 8224
    parameter L2_WEIGHT_BASE = L0_WEIGHTS + L1_WEIGHTS, // 8736
    
    // Requantization scale factors (Q16.16 fixed-point)
    // These values are from scales.json: requantize_scale * 2^16
    parameter signed [31:0] L0_REQUANT_SCALE = 32'd516,   // 0.007874015718698502 * 65536
    parameter signed [31:0] L1_REQUANT_SCALE = 32'd141,   // 0.002151927910745144 * 65536
    parameter signed [31:0] L2_REQUANT_SCALE = 32'd282,   // 0.004303930327296257 * 65536
    
    // Memory file paths
    parameter WEIGHTS_FILE = "C:/Users/koryc/fpga-kws/models/mem/weights_combined.mem",
    parameter LAYER0_BIAS_FILE = "C:/Users/koryc/fpga-kws/models/mem/layer0_bias.mem",
    parameter LAYER1_BIAS_FILE = "C:/Users/koryc/fpga-kws/models/mem/layer1_bias.mem",
    parameter LAYER2_BIAS_FILE = "C:/Users/koryc/fpga-kws/models/mem/layer2_bias.mem"
) (
    input  wire        clk,                    // System clock
    input  wire        rst_n,                  // Active-low reset
    
    // Input interface
    input  wire [2055:0] features,             // 257 int8 input features (257*8 = 2056 bits)
    input  wire          features_valid,       // Start inference
    
    // Output interface
    output reg         inference_done,         // Inference complete (1 cycle pulse)
    output reg         prediction,             // Classification result (0 or 1)
    output reg  [63:0] logits                  // Raw output scores: [31:0]=logit[0], [63:32]=logit[1]
);

    //=========================================================================
    // Internal feature buffer (unpack the input vector)
    //=========================================================================
    reg signed [7:0] features_unpacked [0:256];
    
    integer k;
    always @(*) begin
        for (k = 0; k < 257; k = k + 1) begin
            features_unpacked[k] = features[k*8 +: 8];
        end
    end
    
    //=========================================================================
    // Weight BRAM - Single unified memory for all layers
    //=========================================================================
    // Use ram_style attribute to force BRAM inference
    (* ram_style = "block" *) reg [7:0] weights_bram [0:TOTAL_WEIGHTS-1];
    
    // BRAM read signals
    reg [13:0] weight_addr;       // Address for weight read (up to 8768)
    reg [7:0]  weight_data;       // Data read from BRAM (1-cycle delayed)
    
    // Synchronous BRAM read - this creates the 1-cycle latency
    always @(posedge clk) begin
        weight_data <= weights_bram[weight_addr];
    end
    
    // Initialize weights from combined memory file
    initial begin
        $readmemh(WEIGHTS_FILE, weights_bram);
    end
    
    //=========================================================================
    // Bias Memory (small enough to stay in distributed RAM)
    //=========================================================================
    reg signed [31:0] layer0_bias [0:31];
    reg signed [31:0] layer1_bias [0:15];
    reg signed [31:0] layer2_bias [0:1];
    
    initial begin
        $readmemh(LAYER0_BIAS_FILE, layer0_bias);
        $readmemh(LAYER1_BIAS_FILE, layer1_bias);
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
    reg signed [31:0] mac_accumulator;     // Running sum
    wire signed [15:0] mac_product;
    
    // Pipeline registers for BRAM latency compensation
    reg signed [7:0] weight_pipe;          // Weight from BRAM (pipelined)
    reg signed [7:0] activation_pipe;      // Corresponding activation (pipelined)
    reg              mac_valid;            // Pipeline stage valid flag
    
    // Multiply (combinational) - uses pipelined values
    assign mac_product = weight_pipe * activation_pipe;
    
    //=========================================================================
    // State Machine - Updated for BRAM pipeline
    //=========================================================================
    // Added prefetch states to handle 1-cycle BRAM read latency
    
    localparam STATE_IDLE        = 4'd0;
    localparam STATE_LOAD_INPUT  = 4'd1;
    localparam STATE_L0_PREFETCH = 4'd2;   // Prefetch first weight
    localparam STATE_L0_MAC      = 4'd3;   // Main MAC loop
    localparam STATE_L0_DRAIN    = 4'd4;   // Drain pipeline
    localparam STATE_L0_REQUANT  = 4'd5;
    localparam STATE_L1_PREFETCH = 4'd6;
    localparam STATE_L1_MAC      = 4'd7;
    localparam STATE_L1_DRAIN    = 4'd8;
    localparam STATE_L1_REQUANT  = 4'd9;
    localparam STATE_L2_PREFETCH = 4'd10;
    localparam STATE_L2_MAC      = 4'd11;
    localparam STATE_L2_DRAIN    = 4'd12;
    localparam STATE_L2_REQUANT  = 4'd13;
    localparam STATE_ARGMAX      = 4'd14;
    localparam STATE_DONE        = 4'd15;
    
    reg [3:0] state;
    
    // Loop counters
    reg [8:0] input_idx;      // Current input index being addressed (0 to 256)
    reg [5:0] output_idx;     // Current output neuron (0 to 31)
    
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
    // Pipeline strategy for BRAM:
    //   Cycle N:   Set weight_addr = A, store activation for input A
    //   Cycle N+1: weight_data = weights_bram[A] available
    //   Cycle N+1: Capture into weight_pipe, activation_pipe
    //   Cycle N+1: mac_product = weight_pipe * activation_pipe
    //   Cycle N+2: Accumulate mac_product
    //
    // PREFETCH: Set first address, wait for data
    // MAC:      Pipeline is full, accumulate while fetching next
    // DRAIN:    No more fetches, accumulate remaining products
    
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
            weight_pipe <= 8'd0;
            activation_pipe <= 8'd0;
            mac_valid <= 1'b0;
            
            // Clear outputs
            logits <= 64'd0;
            
        end else begin
            // Default values
            inference_done <= 1'b0;
            
            case (state)
                //-------------------------------------------------------------
                // IDLE: Wait for input features
                //-------------------------------------------------------------
                STATE_IDLE: begin
                    mac_valid <= 1'b0;
                    if (features_valid) begin
                        state <= STATE_LOAD_INPUT;
                        input_idx <= 9'd0;
                    end
                end
                
                //-------------------------------------------------------------
                // LOAD_INPUT: Copy input features to buffer
                //-------------------------------------------------------------
                STATE_LOAD_INPUT: begin
                    input_buffer[input_idx] <= $signed(features_unpacked[input_idx]);
                    
                    if (input_idx == L0_IN - 1) begin
                        // All inputs loaded, prepare for Layer 0
                        state <= STATE_L0_PREFETCH;
                        output_idx <= 6'd0;
                        input_idx <= 9'd0;
                        // Set address for first weight: weight[0, output_idx]
                        // Row-major: weight[i, j] = base + i*num_outputs + j
                        weight_addr <= L0_WEIGHT_BASE + 0;
                        mac_accumulator <= layer0_bias[0];
                        mac_valid <= 1'b0;
                    end else begin
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 0: Prefetch first weight
                //-------------------------------------------------------------
                STATE_L0_PREFETCH: begin
                    // weight_addr already set to weight[0, output_idx]
                    // BRAM will output weight_data next cycle
                    // Prepare address for second weight
                    weight_addr <= L0_WEIGHT_BASE + 1 * L0_OUT + output_idx;
                    input_idx <= 9'd1;  // Next iteration will fetch weight for input 1
                    mac_valid <= 1'b0;  // No valid product yet
                    state <= STATE_L0_MAC;
                end
                
                //-------------------------------------------------------------
                // LAYER 0: MAC loop
                //-------------------------------------------------------------
                // Each cycle:
                //   - weight_data contains weight for (input_idx - 1)
                //   - Capture weight_data and activation[input_idx-1] into pipeline
                //   - Accumulate previous mac_product if valid
                //   - Set address for next weight (input_idx)
                STATE_L0_MAC: begin
                    // Capture weight from BRAM into pipeline
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= input_buffer[input_idx - 1];
                    
                    // Accumulate previous product (if pipeline was valid)
                    if (mac_valid) begin
                        mac_accumulator <= mac_accumulator + $signed(mac_product);
                    end
                    mac_valid <= 1'b1;  // Pipeline now has valid data
                    
                    // Check if we've set address for last weight
                    if (input_idx == L0_IN - 1) begin
                        // Last address set, move to drain
                        state <= STATE_L0_DRAIN;
                    end else begin
                        // Set next weight address
                        weight_addr <= L0_WEIGHT_BASE + (input_idx + 1) * L0_OUT + output_idx;
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 0: Drain pipeline (process last two weights)
                //-------------------------------------------------------------
                STATE_L0_DRAIN: begin
                    // Capture last weight into pipeline
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= input_buffer[L0_IN - 1];
                    
                    // Accumulate previous product
                    mac_accumulator <= mac_accumulator + $signed(mac_product);
                    
                    state <= STATE_L0_REQUANT;
                end
                
                //-------------------------------------------------------------
                // LAYER 0: Requantize and apply ReLU
                //-------------------------------------------------------------
                STATE_L0_REQUANT: begin
                    // Final accumulation with last product
                    layer0_output[output_idx] <= relu(requantize(
                        mac_accumulator + $signed(mac_product),
                        L0_REQUANT_SCALE));
                    
                    mac_valid <= 1'b0;
                    
                    if (output_idx == L0_OUT - 1) begin
                        // All Layer 0 outputs computed, start Layer 1
                        state <= STATE_L1_PREFETCH;
                        output_idx <= 6'd0;
                        input_idx <= 9'd0;
                        weight_addr <= L1_WEIGHT_BASE + 0;
                        mac_accumulator <= layer1_bias[0];
                    end else begin
                        // Move to next output neuron
                        output_idx <= output_idx + 6'd1;
                        input_idx <= 9'd0;
                        weight_addr <= L0_WEIGHT_BASE + (output_idx + 1);
                        mac_accumulator <= layer0_bias[output_idx + 1];
                        state <= STATE_L0_PREFETCH;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 1: Prefetch first weight
                //-------------------------------------------------------------
                STATE_L1_PREFETCH: begin
                    weight_addr <= L1_WEIGHT_BASE + 1 * L1_OUT + output_idx;
                    input_idx <= 9'd1;
                    mac_valid <= 1'b0;
                    state <= STATE_L1_MAC;
                end
                
                //-------------------------------------------------------------
                // LAYER 1: MAC loop
                //-------------------------------------------------------------
                STATE_L1_MAC: begin
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= layer0_output[input_idx - 1];
                    
                    if (mac_valid) begin
                        mac_accumulator <= mac_accumulator + $signed(mac_product);
                    end
                    mac_valid <= 1'b1;
                    
                    if (input_idx == L1_IN - 1) begin
                        state <= STATE_L1_DRAIN;
                    end else begin
                        weight_addr <= L1_WEIGHT_BASE + (input_idx + 1) * L1_OUT + output_idx;
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 1: Drain pipeline
                //-------------------------------------------------------------
                STATE_L1_DRAIN: begin
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= layer0_output[L1_IN - 1];
                    mac_accumulator <= mac_accumulator + $signed(mac_product);
                    state <= STATE_L1_REQUANT;
                end
                
                //-------------------------------------------------------------
                // LAYER 1: Requantize and apply ReLU
                //-------------------------------------------------------------
                STATE_L1_REQUANT: begin
                    layer1_output[output_idx] <= relu(requantize(
                        mac_accumulator + $signed(mac_product),
                        L1_REQUANT_SCALE));
                    
                    mac_valid <= 1'b0;
                    
                    if (output_idx == L1_OUT - 1) begin
                        state <= STATE_L2_PREFETCH;
                        output_idx <= 6'd0;
                        input_idx <= 9'd0;
                        weight_addr <= L2_WEIGHT_BASE + 0;
                        mac_accumulator <= layer2_bias[0];
                    end else begin
                        output_idx <= output_idx + 6'd1;
                        input_idx <= 9'd0;
                        weight_addr <= L1_WEIGHT_BASE + (output_idx + 1);
                        mac_accumulator <= layer1_bias[output_idx + 1];
                        state <= STATE_L1_PREFETCH;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 2: Prefetch first weight
                //-------------------------------------------------------------
                STATE_L2_PREFETCH: begin
                    weight_addr <= L2_WEIGHT_BASE + 1 * L2_OUT + output_idx;
                    input_idx <= 9'd1;
                    mac_valid <= 1'b0;
                    state <= STATE_L2_MAC;
                end
                
                //-------------------------------------------------------------
                // LAYER 2: MAC loop
                //-------------------------------------------------------------
                STATE_L2_MAC: begin
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= layer1_output[input_idx - 1];
                    
                    if (mac_valid) begin
                        mac_accumulator <= mac_accumulator + $signed(mac_product);
                    end
                    mac_valid <= 1'b1;
                    
                    if (input_idx == L2_IN - 1) begin
                        state <= STATE_L2_DRAIN;
                    end else begin
                        weight_addr <= L2_WEIGHT_BASE + (input_idx + 1) * L2_OUT + output_idx;
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 2: Drain pipeline
                //-------------------------------------------------------------
                STATE_L2_DRAIN: begin
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= layer1_output[L2_IN - 1];
                    mac_accumulator <= mac_accumulator + $signed(mac_product);
                    state <= STATE_L2_REQUANT;
                end
                
                //-------------------------------------------------------------
                // LAYER 2: Requantize (no ReLU on final layer)
                //-------------------------------------------------------------
                STATE_L2_REQUANT: begin
                    layer2_output[output_idx] <= requantize(
                        mac_accumulator + $signed(mac_product),
                        L2_REQUANT_SCALE);
                    
                    mac_valid <= 1'b0;
                    
                    if (output_idx == L2_OUT - 1) begin
                        state <= STATE_ARGMAX;
                    end else begin
                        output_idx <= output_idx + 6'd1;
                        input_idx <= 9'd0;
                        weight_addr <= L2_WEIGHT_BASE + (output_idx + 1);
                        mac_accumulator <= layer2_bias[output_idx + 1];
                        state <= STATE_L2_PREFETCH;
                    end
                end
                
                //-------------------------------------------------------------
                // ARGMAX: Compare logits and make prediction
                //-------------------------------------------------------------
                STATE_ARGMAX: begin
                    // Pack logits: [31:0]=logit[0], [63:32]=logit[1]
                    logits[31:0]  <= {{24{layer2_output[0][7]}}, layer2_output[0]};
                    logits[63:32] <= {{24{layer2_output[1][7]}}, layer2_output[1]};
                    
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
