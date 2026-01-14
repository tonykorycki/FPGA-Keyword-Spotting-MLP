//=============================================================================
// Neural Network Inference Engine - Pipelined MAC Version
//=============================================================================
// 3-layer quantized neural network for keyword spotting
// Architecture:
//   Layer 0: 257 inputs -> 32 outputs (Dense + ReLU)
//   Layer 1: 32 inputs  -> 16 outputs (Dense + ReLU)
//   Layer 2: 16 inputs  -> 2 outputs  (Dense, no activation)
//   Output:  argmax(logits) -> prediction (0 or 1)
//
// Quantization: int8 weights, int32 accumulator, int8 activations
// Sequential MAC architecture with 3-stage pipeline
//
// BRAM Optimization:
//   - All weights stored in single BRAM (8,768 x 8-bit)
//   - Pipelined reads to handle 1-cycle BRAM latency
//   - Biases remain in distributed RAM (only 50 values)
//
// MAC Pipeline (3 cycles total):
//   Stage 1: Multiply (weight × activation) -> product_reg
//   Stage 2: Add (product + accumulator) -> sum_reg
//   Stage 3: Accumulate (sum -> accumulator)
//
// Address layout in unified weight BRAM:
//   0-8223:     layer0_weights (257×32)
//   8224-8735:  layer1_weights (32×16)
//   8736-8767:  layer2_weights (16×2)
//
// Author: Tony Korycki
// Date: January 14, 2026
// Modified from: inference.v - Added MAC pipeline for timing closure
//=============================================================================

module inference_pipelined #(
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
    
    //=========================================================================
    // MAC Pipeline - 3 Stage
    //=========================================================================
    // Stage 0: Input capture from BRAM
    reg signed [7:0] weight_pipe;          // Weight from BRAM
    reg signed [7:0] activation_pipe;      // Corresponding activation
    reg              pipe0_valid;          // Stage 0 valid
    
    // Stage 1: Multiply (DSP-based)
    reg signed [15:0] product_reg;         // Multiplication result
    reg               pipe1_valid;         // Stage 1 valid
    wire signed [15:0] mac_product;
    (* use_dsp = "yes" *) assign mac_product = weight_pipe * activation_pipe;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_reg <= 16'd0;
            pipe1_valid <= 1'b0;
        end else begin
            product_reg <= mac_product;
            pipe1_valid <= pipe0_valid;
        end
    end
    
    // Stage 2: Add to accumulator
    reg signed [31:0] sum_reg;             // Addition result
    reg               pipe2_valid;         // Stage 2 valid
    reg signed [31:0] mac_accumulator;     // Running sum
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_reg <= 32'd0;
            pipe2_valid <= 1'b0;
        end else begin
            sum_reg <= mac_accumulator + $signed(product_reg);
            pipe2_valid <= pipe1_valid;
        end
    end
    
    // Stage 3: Write back to accumulator (in main FSM)
    
    //=========================================================================
    // State Machine - Updated for 3-cycle MAC pipeline
    //=========================================================================
    
    localparam STATE_IDLE        = 4'd0;
    localparam STATE_LOAD_INPUT  = 4'd1;
    localparam STATE_L0_PREFETCH = 4'd2;   // Prefetch first weight
    localparam STATE_L0_MAC      = 4'd3;   // Main MAC loop
    localparam STATE_L0_DRAIN1   = 4'd4;   // Drain cycle 1
    localparam STATE_L0_DRAIN2   = 4'd5;   // Drain cycle 2
    localparam STATE_L0_DRAIN3   = 4'd6;   // Drain cycle 3
    localparam STATE_L0_REQUANT  = 4'd7;
    localparam STATE_L1_PREFETCH = 4'd8;
    localparam STATE_L1_MAC      = 4'd9;
    localparam STATE_L1_DRAIN1   = 4'd10;
    localparam STATE_L1_DRAIN2   = 4'd11;
    localparam STATE_L1_DRAIN3   = 4'd12;
    localparam STATE_L1_REQUANT  = 4'd13;
    // Need to extend to 5 bits for more states
    localparam STATE_L2_PREFETCH = 5'd14;
    localparam STATE_L2_MAC      = 5'd15;
    localparam STATE_L2_DRAIN1   = 5'd16;
    localparam STATE_L2_DRAIN2   = 5'd17;
    localparam STATE_L2_DRAIN3   = 5'd18;
    localparam STATE_L2_REQUANT  = 5'd19;
    localparam STATE_ARGMAX      = 5'd20;
    localparam STATE_DONE        = 5'd21;
    
    reg [4:0] state;  // Extended to 5 bits
    
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
    // Pipeline strategy:
    //   Cycle N:   Feed weight/activation into pipe0 (weight_pipe, activation_pipe)
    //   Cycle N+1: Multiply result in product_reg (pipe1)
    //   Cycle N+2: Add result in sum_reg (pipe2)
    //   Cycle N+3: Write sum_reg to mac_accumulator (pipe3)
    //
    // PREFETCH: Prime BRAM, wait for first weight
    // MAC:      Feed pipeline, accumulate valid results
    // DRAIN:    Stop feeding, let pipeline flush (3 cycles)
    
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
            pipe0_valid <= 1'b0;
            logits <= 64'd0;
            
        end else begin
            // Default values
            inference_done <= 1'b0;
            
            case (state)
                //-------------------------------------------------------------
                // IDLE: Wait for input features
                //-------------------------------------------------------------
                STATE_IDLE: begin
                    pipe0_valid <= 1'b0;
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
                        weight_addr <= L0_WEIGHT_BASE + 0;
                        mac_accumulator <= layer0_bias[0];
                        pipe0_valid <= 1'b0;
                    end else begin
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 0: Prefetch first weight
                //-------------------------------------------------------------
                STATE_L0_PREFETCH: begin
                    // BRAM will output weight_data next cycle
                    weight_addr <= L0_WEIGHT_BASE + 1 * L0_OUT + output_idx;
                    input_idx <= 9'd1;
                    pipe0_valid <= 1'b0;
                    state <= STATE_L0_MAC;
                end
                
                //-------------------------------------------------------------
                // LAYER 0: MAC loop with pipelined accumulation
                //-------------------------------------------------------------
                STATE_L0_MAC: begin
                    // Feed pipeline stage 0
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= input_buffer[input_idx - 1];
                    pipe0_valid <= 1'b1;
                    
                    // Accumulate from pipeline stage 3
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    // Check if we've issued last weight fetch
                    if (input_idx == L0_IN - 1) begin
                        state <= STATE_L0_DRAIN1;
                    end else begin
                        weight_addr <= L0_WEIGHT_BASE + (input_idx + 1) * L0_OUT + output_idx;
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 0: Drain pipeline (3 cycles to flush)
                //-------------------------------------------------------------
                STATE_L0_DRAIN1: begin
                    // Feed last weight into pipeline
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= input_buffer[L0_IN - 1];
                    pipe0_valid <= 1'b1;
                    
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L0_DRAIN2;
                end
                
                STATE_L0_DRAIN2: begin
                    pipe0_valid <= 1'b0;  // Stop feeding pipeline
                    
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L0_DRAIN3;
                end
                
                STATE_L0_DRAIN3: begin
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L0_REQUANT;
                end
                
                //-------------------------------------------------------------
                // LAYER 0: Requantize and apply ReLU
                //-------------------------------------------------------------
                STATE_L0_REQUANT: begin
                    layer0_output[output_idx] <= relu(requantize(
                        mac_accumulator,
                        L0_REQUANT_SCALE));
                    
                    if (output_idx == L0_OUT - 1) begin
                        // All Layer 0 outputs computed
                        state <= STATE_L1_PREFETCH;
                        output_idx <= 6'd0;
                        input_idx <= 9'd0;
                        weight_addr <= L1_WEIGHT_BASE + 0;
                        mac_accumulator <= layer1_bias[0];
                    end else begin
                        // Next output neuron
                        output_idx <= output_idx + 6'd1;
                        input_idx <= 9'd0;
                        weight_addr <= L0_WEIGHT_BASE + (output_idx + 1);
                        mac_accumulator <= layer0_bias[output_idx + 1];
                        state <= STATE_L0_PREFETCH;
                    end
                end
                
                //-------------------------------------------------------------
                // LAYER 1: Similar structure to Layer 0
                //-------------------------------------------------------------
                STATE_L1_PREFETCH: begin
                    weight_addr <= L1_WEIGHT_BASE + 1 * L1_OUT + output_idx;
                    input_idx <= 9'd1;
                    pipe0_valid <= 1'b0;
                    state <= STATE_L1_MAC;
                end
                
                STATE_L1_MAC: begin
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= layer0_output[input_idx - 1];
                    pipe0_valid <= 1'b1;
                    
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    if (input_idx == L1_IN - 1) begin
                        state <= STATE_L1_DRAIN1;
                    end else begin
                        weight_addr <= L1_WEIGHT_BASE + (input_idx + 1) * L1_OUT + output_idx;
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                STATE_L1_DRAIN1: begin
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= layer0_output[L1_IN - 1];
                    pipe0_valid <= 1'b1;
                    
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L1_DRAIN2;
                end
                
                STATE_L1_DRAIN2: begin
                    pipe0_valid <= 1'b0;
                    
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L1_DRAIN3;
                end
                
                STATE_L1_DRAIN3: begin
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L1_REQUANT;
                end
                
                STATE_L1_REQUANT: begin
                    layer1_output[output_idx] <= relu(requantize(
                        mac_accumulator,
                        L1_REQUANT_SCALE));
                    
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
                // LAYER 2: Similar structure to Layer 0/1
                //-------------------------------------------------------------
                STATE_L2_PREFETCH: begin
                    weight_addr <= L2_WEIGHT_BASE + 1 * L2_OUT + output_idx;
                    input_idx <= 9'd1;
                    pipe0_valid <= 1'b0;
                    state <= STATE_L2_MAC;
                end
                
                STATE_L2_MAC: begin
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= layer1_output[input_idx - 1];
                    pipe0_valid <= 1'b1;
                    
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    if (input_idx == L2_IN - 1) begin
                        state <= STATE_L2_DRAIN1;
                    end else begin
                        weight_addr <= L2_WEIGHT_BASE + (input_idx + 1) * L2_OUT + output_idx;
                        input_idx <= input_idx + 9'd1;
                    end
                end
                
                STATE_L2_DRAIN1: begin
                    weight_pipe <= $signed(weight_data);
                    activation_pipe <= layer1_output[L2_IN - 1];
                    pipe0_valid <= 1'b1;
                    
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L2_DRAIN2;
                end
                
                STATE_L2_DRAIN2: begin
                    pipe0_valid <= 1'b0;
                    
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L2_DRAIN3;
                end
                
                STATE_L2_DRAIN3: begin
                    if (pipe2_valid) begin
                        mac_accumulator <= sum_reg;
                    end
                    
                    state <= STATE_L2_REQUANT;
                end
                
                STATE_L2_REQUANT: begin
                    layer2_output[output_idx] <= requantize(
                        mac_accumulator,
                        L2_REQUANT_SCALE);
                    
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
                    logits[31:0]  <= {{24{layer2_output[0][7]}}, layer2_output[0]};
                    logits[63:32] <= {{24{layer2_output[1][7]}}, layer2_output[1]};
                    
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
