// Feature Extractor Module
// Extracts MFCC-like features from audio frames
// Author: 
// Date: October 17, 2025

module feature_extractor (
    input wire clk,                  // System clock
    input wire rst_n,                // Active low reset
    input wire frame_ready,          // Frame ready signal
    input wire [15:0] frame_data [0:255], // Input frame data (256 samples)
    output reg features_ready,       // Features ready signal
    output reg [7:0] features [0:31] // Output features (32 8-bit features)
);

    // Parameters
    parameter FFT_SIZE = 256;
    parameter NUM_FEATURES = 32;

    // Internal signals
    reg fft_start;
    wire fft_done;
    reg [15:0] fft_in_real [0:FFT_SIZE-1];
    reg [15:0] fft_in_imag [0:FFT_SIZE-1];
    wire [15:0] fft_out_real [0:FFT_SIZE-1];
    wire [15:0] fft_out_imag [0:FFT_SIZE-1];
    reg [31:0] mag_squared [0:FFT_SIZE/2-1]; // FFT magnitude squared
    reg [15:0] mel_energies [0:NUM_FEATURES-1]; // Mel-scaled filter bank energies
    
    // State machine states
    localparam IDLE = 3'd0;
    localparam PREPARE_FFT = 3'd1;
    localparam COMPUTE_FFT = 3'd2;
    localparam COMPUTE_MAGNITUDES = 3'd3;
    localparam APPLY_MEL_FILTERS = 3'd4;
    localparam COMPUTE_LOG = 3'd5;
    localparam FINISH = 3'd6;
    
    reg [2:0] state;
    reg [8:0] counter; // General purpose counter
    
    // Instantiate FFT core
    fft_core #(
        .DATA_WIDTH(16),
        .FFT_POINTS(FFT_SIZE),
        .TWIDDLE_WIDTH(16)
    ) fft_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(fft_start),
        .x_real(fft_in_real),
        .x_imag(fft_in_imag),
        .done(fft_done),
        .y_real(fft_out_real),
        .y_imag(fft_out_imag)
    );
    
    // Mel filter bank coefficients would be stored in ROM
    // This is a simplified implementation that assumes they're available
    wire [15:0] mel_filter_coefs [0:NUM_FEATURES-1][0:FFT_SIZE/2-1];
    
    // Feature extraction process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fft_start <= 1'b0;
            features_ready <= 1'b0;
            counter <= 9'd0;
        end else begin
            // Default values
            fft_start <= 1'b0;
            features_ready <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (frame_ready) begin
                        state <= PREPARE_FFT;
                        counter <= 9'd0;
                    end
                end
                
                PREPARE_FFT: begin
                    // Copy frame data to FFT input (real part)
                    // Zero out imaginary part
                    if (counter < FFT_SIZE) begin
                        fft_in_real[counter] <= frame_data[counter];
                        fft_in_imag[counter] <= 16'd0;
                        counter <= counter + 9'd1;
                    end else begin
                        state <= COMPUTE_FFT;
                        fft_start <= 1'b1;
                    end
                end
                
                COMPUTE_FFT: begin
                    if (fft_done) begin
                        state <= COMPUTE_MAGNITUDES;
                        counter <= 9'd0;
                    end
                end
                
                COMPUTE_MAGNITUDES: begin
                    // Compute magnitude squared for half of FFT (due to symmetry)
                    if (counter < FFT_SIZE/2) begin
                        // Magnitude squared = real^2 + imag^2
                        mag_squared[counter] <= 
                            (fft_out_real[counter] * fft_out_real[counter] + 
                             fft_out_imag[counter] * fft_out_imag[counter]) >> 8; // Scale down to avoid overflow
                        counter <= counter + 9'd1;
                    end else begin
                        state <= APPLY_MEL_FILTERS;
                        counter <= 9'd0;
                    end
                end
                
                APPLY_MEL_FILTERS: begin
                    // Apply mel filter bank
                    if (counter < NUM_FEATURES) begin
                        // In a real implementation, this would involve dot products
                        // between filter coefficients and FFT magnitudes
                        // Here we're using a simplified placeholder
                        mel_energies[counter] <= 16'd0; // Placeholder
                        counter <= counter + 9'd1;
                    end else begin
                        state <= COMPUTE_LOG;
                        counter <= 9'd0;
                    end
                end
                
                COMPUTE_LOG: begin
                    // Compute log of filter bank energies
                    if (counter < NUM_FEATURES) begin
                        // In a real implementation, this would use a log lookup table
                        // Here we're using a simplified quantization to 8 bits
                        features[counter] <= mel_energies[counter][15:8];
                        counter <= counter + 9'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    features_ready <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
