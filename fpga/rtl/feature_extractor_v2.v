//=============================================================================
// Feature Extractor V2 - Serial Bin Input (NOT ROUTED)
//=============================================================================
// Alternative to feature_extractor.v that processes FFT bins one at a time
// instead of receiving the entire 8224-bit packed vector.
//
// Benefits over original:
//   - Eliminates 257-element fft_real/fft_imag unpack (no 257-way read mux)
//   - Eliminates 257-element magnitude[] intermediate array (saves ~8K bits)
//   - Single-pass processing: mag + log + store in one cycle per bin
//   - Reduces combinational depth and MUX count significantly
//
// To integrate, modify fft_core to output bins serially during STATE_COLLECT
// instead of packing into fft_bins_packed. Wire fft_bin_data/valid/last from
// fft_core's collection loop directly into this module.
//
// Required fft_core changes for integration:
//   1. Add output ports: fft_bin_data[31:0], fft_bin_valid, fft_bin_last
//   2. In STATE_COLLECT, drive fft_bin_data <= data_out_tdata,
//      fft_bin_valid <= (data_out_tvalid && data_out_tready),
//      fft_bin_last  <= (data_out_tlast || sample_counter == 256)
//   3. Remove fft_bins_packed output and bin_real/bin_imag arrays
//
// Input:  Serial FFT bins: 32-bit per cycle ([31:16]=real, [15:0]=imag)
// Output: 257 INT8 features (2056 bits packed)
//
// Author: Tony Korycki
// Date: February 13, 2026
//=============================================================================

module feature_extractor_v2 (
    input  wire        clk,
    input  wire        rst_n,
    
    // Serial bin input (one bin per cycle from FFT core)
    input  wire [31:0] fft_bin_data,       // One complex bin: [31:16]=real, [15:0]=imag
    input  wire        fft_bin_valid,      // Bin data is valid this cycle
    input  wire        fft_bin_last,       // Marks last bin (bin 256)
    output reg         fft_consumed,       // Asserted when all bins have been processed
    
    // Output interface - packed INT8 features
    output reg [2055:0] features_packed,   // 257 features x 8 bits
    output reg          features_valid     // Features ready for downstream
);

    //=========================================================================
    // State Machine
    //=========================================================================
    localparam STATE_IDLE    = 2'd0;
    localparam STATE_PROCESS = 2'd1;
    localparam STATE_DONE    = 2'd2;
    
    reg [1:0] state;
    reg [8:0] bin_count;  // 0-256 (257 bins)
    
    //=========================================================================
    // Combinational Feature Computation (no intermediate storage needed)
    //=========================================================================
    
    // Extract real and imaginary from current bin
    wire signed [15:0] cur_real = fft_bin_data[31:16];
    wire signed [15:0] cur_imag = fft_bin_data[15:0];
    
    // Manhattan distance magnitude (cheaper than Euclidean)
    // |real| + |imag| approximates sqrt(real^2 + imag^2)
    wire [31:0] abs_real = (cur_real < 0) ? (-cur_real) : cur_real;
    wire [31:0] abs_imag = (cur_imag < 0) ? (-cur_imag) : cur_imag;
    wire [31:0] magnitude = abs_real + abs_imag;
    
    // Log2 approximation using leading-one detection
    // Matches original feature_extractor.v implementation exactly
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
                    found_one = 1;
            end
            if (val == 0)
                log2_approx = 8'd0;
            else
                log2_approx = 8'd32 - leading_zeros;
        end
    endfunction
    
    // Scale log value to match training distribution
    // Training uses log1p -> normalize -> x127, giving range [0,127]
    // FPGA log2 gives [0,17] for 16-bit inputs, shift left 3 to approximate
    // Max: 17 << 3 = 136, clamped to 127
    wire [7:0] raw_log    = log2_approx(magnitude);
    wire [7:0] scaled_log = raw_log << 3;
    wire [7:0] feature_val = (scaled_log > 8'd127) ? 8'd127 : scaled_log;
    
    //=========================================================================
    // Main State Machine - Single Pass (1 cycle per bin, no multi-stage)
    //=========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            bin_count      <= 9'd0;
            fft_consumed   <= 1'b0;
            features_valid <= 1'b0;
        end else begin
            case (state)
                //-------------------------------------------------------------
                STATE_IDLE: begin
                //-------------------------------------------------------------
                    fft_consumed   <= 1'b0;
                    features_valid <= 1'b0;
                    bin_count      <= 9'd0;
                    
                    if (fft_bin_valid) begin
                        // Process first bin immediately
                        features_packed[7:0] <= feature_val;
                        bin_count <= 9'd1;
                        state <= fft_bin_last ? STATE_DONE : STATE_PROCESS;
                    end
                end
                
                //-------------------------------------------------------------
                STATE_PROCESS: begin
                //-------------------------------------------------------------
                    if (fft_bin_valid) begin
                        // Compute and store feature in one cycle per bin
                        // Write-demux is efficient (decoder, not mux tree)
                        features_packed[bin_count*8 +: 8] <= feature_val;
                        
                        if (fft_bin_last || bin_count == 9'd256) begin
                            fft_consumed <= 1'b1;
                            state <= STATE_DONE;
                        end else begin
                            bin_count <= bin_count + 9'd1;
                        end
                    end
                end
                
                //-------------------------------------------------------------
                STATE_DONE: begin
                //-------------------------------------------------------------
                    features_valid <= 1'b1;
                    fft_consumed   <= 1'b0;
                    state <= STATE_IDLE;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
