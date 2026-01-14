// Frame Buffer Module
// This module buffers audio samples into frames for processing
// Author: 
// Date: October 17, 2025

module frame_buffer (
    input wire clk,                  // System clock
    input wire rst_n,                // Active low reset
    input wire [15:0] audio_sample,  // Input audio sample
    input wire sample_valid,         // Sample valid signal
    input wire frame_consumed,       // Signal that downstream has consumed the frame
    output reg frame_ready,          // Frame ready signal
    output wire [8191:0] frame_data_packed  // Frame data (512 samples × 16 bits = 8192 bits)
);

    // Parameters
    parameter FRAME_SIZE = 512;  // Number of samples per frame (for 512-point FFT)
    parameter FRAME_OVERLAP = 256; // 50% overlap between consecutive frames

    // Internal registers
    reg [15:0] buffer [0:FRAME_SIZE*2-1]; // Double buffer to handle overlap (1024 samples)
    reg [9:0] write_ptr;  // Pointer to current write position (0-1023)
    reg processing;       // Flag indicating if frame is being processed
    reg buffer_filled;    // Set after first 512 samples collected

    // Frame ready logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 10'd0;
            frame_ready <= 1'b0;
            processing <= 1'b0;
            buffer_filled <= 1'b0;
        end else begin
            // Reset frame_ready pulse
            frame_ready <= 1'b0;
            
            // If sample is valid, store it and advance pointer
            if (sample_valid) begin
                buffer[write_ptr] <= audio_sample;
                
                // Check if we've collected enough samples for a new frame
                // Trigger every FRAME_OVERLAP (256) samples for 50% overlap
                // Trigger points: 511, 767, 1023, 255, 511, 767... (every 256 samples)
                // Condition: lower 8 bits = 255, AND (ptr >= 511 OR buffer already filled)
                if (!processing && (write_ptr[7:0] == 8'd255) && 
                    (write_ptr >= 10'd511 || buffer_filled)) begin
                    frame_ready <= 1'b1;
                    processing <= 1'b1;
                    buffer_filled <= 1'b1;  // Mark as filled after first frame
                end
                
                // Increment write pointer with wraparound after checking trigger
                if (write_ptr >= (FRAME_SIZE*2 - 1))
                    write_ptr <= 10'd0;
                else
                    write_ptr <= write_ptr + 10'd1;
            end
            
            // Reset processing flag when frame is consumed
            if (processing && frame_consumed) begin
                processing <= 1'b0;
            end
        end
    end

    // Output frame data as packed bit vector
    // Extract 512 contiguous samples starting from the oldest position
    reg [9:0] read_base;
    
    always @(*) begin
        // Determine read base: oldest sample in the window
        if (write_ptr >= FRAME_SIZE)
            read_base = write_ptr - FRAME_SIZE;
        else
            read_base = write_ptr + FRAME_SIZE;
    end
    
    // Pack 512 samples into output bit vector
    genvar i;
    generate
        for (i = 0; i < FRAME_SIZE; i = i + 1) begin: FRAME_OUTPUT
            wire [9:0] read_addr;
            assign read_addr = (read_base + i >= FRAME_SIZE*2) ? 
                              (read_base + i - FRAME_SIZE*2) : (read_base + i);
            assign frame_data_packed[i*16 +: 16] = buffer[read_addr];
        end
    endgenerate

endmodule