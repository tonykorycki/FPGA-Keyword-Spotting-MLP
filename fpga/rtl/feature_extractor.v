//=============================================================================
// Feature Extractor Module
//=============================================================================
// Converts FFT complex spectrum to log-magnitude INT8 features
// Matches Python's: np.log1p(np.abs(fft)) then quantize to INT8
//
// Input:  257 complex bins (8224 bits = 257×32, [15:0]=imag, [31:16]=real)
// Output: 257 INT8 features (2056 bits = 257×8)
//
// Author: Tony Korycki
// Date: November 19, 2025
//=============================================================================

module feature_extractor (
    input  wire        clk,                      // System clock
    input  wire        rst_n,                    // Active low reset
    
    // Input interface - packed FFT bins from fft_core
    input  wire [8223:0] fft_bins_packed,        // 257 bins × 32 bits (real+imag)
    input  wire          fft_valid,              // FFT output ready
    output reg           fft_consumed,           // FFT data consumed
    
    // Output interface - packed INT8 features
    output reg [2055:0]  features_packed,        // 257 features × 8 bits
    output reg           features_valid          // Features ready
);

    //=========================================================================
    // State Machine
    //=========================================================================
    localparam STATE_IDLE         = 3'd0;
    localparam STATE_COMPUTE_MAG  = 3'd1;
    localparam STATE_FIND_MAX     = 3'd2;
    localparam STATE_LOG_SCALE    = 3'd3;
    localparam STATE_QUANTIZE     = 3'd4;
    localparam STATE_DONE         = 3'd5;
    
    reg [2:0] state;
    reg [8:0] bin_index;  // 0-256 (257 bins)
    
    //=========================================================================
    // Unpack FFT Bins (Real and Imaginary Parts)
    //=========================================================================
    wire signed [15:0] fft_real [0:256];
    wire signed [15:0] fft_imag [0:256];
    
    genvar g;
    generate
        for (g = 0; g < 257; g = g + 1) begin : unpack_fft
            assign fft_real[g] = fft_bins_packed[g*32 + 16 +: 16];  // [31:16] = real
            assign fft_imag[g] = fft_bins_packed[g*32 +: 16];       // [15:0] = imag
        end
    endgenerate
    
    //=========================================================================
    // Magnitude Computation (Manhattan Distance - More FPGA Friendly)
    //=========================================================================
    // mag[i] = |real[i]| + |imag[i]|  (cheaper than sqrt)
    // Close approximation to Euclidean distance for scaling purposes
    
    // Use distributed RAM (sync reset already applied to state machine)
    reg [31:0] magnitude [0:256];       // Magnitude values (unsigned)
    reg [31:0] max_magnitude;           // Maximum magnitude for scaling
    reg [31:0] current_mag;
    
    // Absolute value helper
    function [31:0] abs_value;
        input signed [15:0] val;
        begin
            abs_value = (val < 0) ? -val : val;
        end
    endfunction
    
    //=========================================================================
    // Log Approximation (Base-2 using Leading Zero Count)
    //=========================================================================
    // log2(x) ≈ 16 - leading_zeros(x)
    // This gives rough logarithmic scaling matching np.log1p behavior
    
    function [7:0] log2_approx;
        input [31:0] val;
        reg [5:0] leading_zeros;
        integer i;
        reg found_one;
        begin
            leading_zeros = 0;
            found_one = 0;
            for (i = 31; i >= 0; i = i - 1) begin
                if (val[i] == 1'b0 && !found_one)
                    leading_zeros = leading_zeros + 1;
                else if (val[i] == 1'b1)
                    found_one = 1;  // Stop counting zeros once we see a 1
            end
            
            if (val == 0)
                log2_approx = 8'd0;
            else
                log2_approx = 8'd32 - leading_zeros;
        end
    endfunction
    
    //=========================================================================
    // Feature Buffer (Intermediate Storage) - No async reset for RAM
    //=========================================================================
    reg [7:0] features [0:256];
    
    //=========================================================================
    // Main State Machine - Synchronous reset for RAM compatibility
    //=========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            bin_index <= 9'd0;
            fft_consumed <= 1'b0;
            features_valid <= 1'b0;
            max_magnitude <= 32'd0;
            current_mag <= 32'd0;
            
        end else begin
            case (state)
                
                //=============================================================
                STATE_IDLE: begin
                //=============================================================
                    fft_consumed <= 1'b0;
                    features_valid <= 1'b0;
                    
                    if (fft_valid) begin
                        bin_index <= 9'd0;
                        max_magnitude <= 32'd0;
                        state <= STATE_COMPUTE_MAG;
                        fft_consumed <= 1'b1;  // Acknowledge FFT data
                    end
                end
                
                //=============================================================
                STATE_COMPUTE_MAG: begin
                //=============================================================
                    // Compute magnitude for current bin
                    // Use non-blocking for registered outputs
                    current_mag <= abs_value(fft_real[bin_index]) + 
                                   abs_value(fft_imag[bin_index]);
                    magnitude[bin_index] <= abs_value(fft_real[bin_index]) + 
                                            abs_value(fft_imag[bin_index]);
                    
                    // Track maximum (compare against newly computed value)
                    if ((abs_value(fft_real[bin_index]) + abs_value(fft_imag[bin_index])) > max_magnitude)
                        max_magnitude <= abs_value(fft_real[bin_index]) + abs_value(fft_imag[bin_index]);
                    
                    if (bin_index == 9'd256) begin
                        bin_index <= 9'd0;
                        state <= STATE_LOG_SCALE;
                    end else begin
                        bin_index <= bin_index + 9'd1;
                    end
                end
                
                //=============================================================
                STATE_LOG_SCALE: begin
                //=============================================================
                    // Apply log approximation and scale to match quantized training data
                    // Training uses log1p → normalize → ×127, giving range [0,127]
                    // FPGA log2 gives [0,16], so multiply by 8 (shift left 3) to match
                    // Clamp to 127 to avoid overflow into negative signed INT8 range
                    begin : log_scale_block
                        reg [7:0] scaled_log;
                        scaled_log = log2_approx(magnitude[bin_index]) << 3;
                        features[bin_index] <= (scaled_log > 8'd127) ? 8'd127 : scaled_log;
                    end
                    
                    if (bin_index == 9'd256) begin
                        bin_index <= 9'd0;
                        state <= STATE_QUANTIZE;
                    end else begin
                        bin_index <= bin_index + 9'd1;
                    end
                end
                
                //=============================================================
                STATE_QUANTIZE: begin
                //=============================================================
                    // Normalize to INT8 range [-127, 127]
                    // Simple scaling: scale = feature * 127 / max(features)
                    // For now, just pass through (normalization can be done in Python training)
                    
                    // Pack features into output
                    features_packed[bin_index*8 +: 8] <= features[bin_index];
                    
                    if (bin_index == 9'd256) begin
                        state <= STATE_DONE;
                    end else begin
                        bin_index <= bin_index + 9'd1;
                    end
                end
                
                //=============================================================
                STATE_DONE: begin
                //=============================================================
                    features_valid <= 1'b1;
                    state <= STATE_IDLE;
                end
                
                //=============================================================
                default: state <= STATE_IDLE;
                //=============================================================
                
            endcase
        end
    end

endmodule
