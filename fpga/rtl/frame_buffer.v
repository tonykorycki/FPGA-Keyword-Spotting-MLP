// Frame Buffer Module
// This module buffers audio samples into frames for processing
// Author: 
// Date: October 17, 2025

module frame_buffer (
    input wire clk,                  // System clock
    input wire rst_n,                // Active low reset
    input wire [15:0] audio_sample,  // Input audio sample
    input wire sample_valid,         // Sample valid signal
    output reg frame_ready,          // Frame ready signal
    output wire [15:0] frame_data [0:255] // Frame data (256 samples)
);

    // Parameters
    parameter FRAME_SIZE = 256;  // Number of samples per frame
    parameter FRAME_OVERLAP = 128; // Overlap between consecutive frames

    // Internal registers
    reg [15:0] buffer [0:FRAME_SIZE*2-1]; // Double buffer to handle overlap
    reg [9:0] write_ptr;  // Pointer to current write position
    reg processing;       // Flag indicating if frame is being processed

    // Frame ready logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 10'd0;
            frame_ready <= 1'b0;
            processing <= 1'b0;
        end else begin
            // Reset frame_ready pulse
            frame_ready <= 1'b0;
            
            // If sample is valid, store it and advance pointer
            if (sample_valid) begin
                buffer[write_ptr] <= audio_sample;
                write_ptr <= (write_ptr + 10'd1) % (FRAME_SIZE*2);
                
                // Check if we've collected enough samples for a new frame
                if (!processing && (write_ptr == FRAME_SIZE - 1 || 
                                   write_ptr == FRAME_SIZE*2 - 1)) begin
                    frame_ready <= 1'b1;
                    processing <= 1'b1;
                end
            end
            
            // Reset processing flag when signaled from feature extractor
            // This would normally come from a handshake signal we're not showing here
            if (processing && /* signal from feature extractor */ 1'b0) begin
                processing <= 1'b0;
            end
        end
    end

    // Output frame data
    // In a real implementation, this would be handled through a proper memory interface
    // For simplicity, we're directly exposing the buffer
    genvar i;
    generate
        for (i = 0; i < FRAME_SIZE; i = i + 1) begin: FRAME_OUTPUT
            assign frame_data[i] = buffer[(write_ptr >= FRAME_SIZE) ? 
                                         (i + write_ptr - FRAME_SIZE) % (FRAME_SIZE*2) : 
                                         (i + write_ptr + FRAME_SIZE) % (FRAME_SIZE*2)];
        end
    endgenerate

endmodule