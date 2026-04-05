// Frame Buffer Module
// This module buffers audio samples into frames for processing
// Author: 
// Date: October 17, 2025
// Modified: January 14, 2026 - Sync reset for RAM to enable BRAM inference

module frame_buffer (
    input wire clk,                  // System clock
    input wire rst_n,                // Active low reset
    input wire [15:0] audio_sample,  // Input audio sample
    input wire sample_valid,         // Sample valid signal
    input wire frame_consumed,       // Signal that downstream has consumed the frame
    output reg frame_ready,          // Frame ready signal (pulses when new frame available)
    output reg [15:0] frame_sample,  // Serial output: one sample per cycle
    output reg frame_sample_valid    // Valid signal for serial output
);

    // Parameters
    parameter FRAME_SIZE = 512;  // Number of samples per frame (for 512-point FFT)
    parameter FRAME_OVERLAP = 256; // 50% overlap between consecutive frames

    // Internal registers - BRAM-friendly with serial access
    (* ram_style = "block" *) reg [15:0] buffer [0:FRAME_SIZE*2-1]; // Double buffer (1024 samples)
    (* mark_debug = "true" *) reg [9:0] write_ptr;  // Pointer to current write position (0-1023)
    (* mark_debug = "true" *) reg processing;       // Flag indicating if frame is being processed
    reg buffer_filled;    // Set after first 512 samples collected
    
    // Serialization state machine
    localparam READ_IDLE = 1'b0;
    localparam READ_STREAM = 1'b1;
    
    reg read_state;
    reg [9:0] read_ptr;   // Pointer for serial readout
    reg [8:0] read_count; // Count samples read (0-511)
    (* mark_debug = "true" *) reg read_done;        // Prevents re-trigger while frame_ready is level-high

    // Write control logic with synchronous reset
    always @(posedge clk) begin
        if (!rst_n) begin
            write_ptr <= 10'd0;
            frame_ready <= 1'b0;
            processing <= 1'b0;
            buffer_filled <= 1'b0;
        end else begin
            
            // If sample is valid, store it and advance pointer
            if (sample_valid) begin
                buffer[write_ptr] <= audio_sample;
                
                // Check if we've collected enough samples for a new frame
                // Trigger every FRAME_OVERLAP (256) samples for 50% overlap
                // Trigger points: 511, 767, 1023, 255, 511, 767... (every 256 samples)
                // Condition: lower 8 bits = 255, AND (ptr >= 511 OR buffer already filled)
                if (!processing && (write_ptr[7:0] == 8'd255) && 
                    (write_ptr >= 10'd511 || buffer_filled)) begin
                    frame_ready <= 1'b1;  // Set high and keep high
                    processing <= 1'b1;
                    buffer_filled <= 1'b1;  // Mark as filled after first frame
                end
                
                // Increment write pointer with wraparound after checking trigger
                if (write_ptr >= (FRAME_SIZE*2 - 1))
                    write_ptr <= 10'd0;
                else
                    write_ptr <= write_ptr + 10'd1;
            end
            
            // Reset processing flag and frame_ready when frame is consumed
            if (processing && frame_consumed) begin
                processing <= 1'b0;
                frame_ready <= 1'b0;  // Clear when consumed
            end
        end
    end

    // Serial readout state machine
    reg [9:0] read_base;
    
    always @(*) begin
        // Determine read base: oldest sample in the window
        if (write_ptr >= FRAME_SIZE)
            read_base = write_ptr - FRAME_SIZE;
        else
            read_base = write_ptr + FRAME_SIZE;
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            read_state <= READ_IDLE;
            read_ptr <= 10'd0;
            read_count <= 9'd0;
            frame_sample <= 16'd0;
            frame_sample_valid <= 1'b0;
            read_done <= 1'b0;
        end else begin
            case (read_state)
                READ_IDLE: begin
                    frame_sample_valid <= 1'b0;
                    // Only trigger once per frame_ready assertion
                    if (frame_ready && !read_done) begin
                        // Start streaming out frame
                        read_ptr <= read_base;
                        read_count <= 9'd0;
                        read_state <= READ_STREAM;
                        read_done <= 1'b1;
                    end
                    // Clear guard after frame_ready deasserts (frame consumed)
                    if (!frame_ready) begin
                        read_done <= 1'b0;
                    end
                end
                
                READ_STREAM: begin
                    // Output one sample per cycle
                    frame_sample <= buffer[read_ptr];
                    frame_sample_valid <= 1'b1;
                    
                    // Advance read pointer with wraparound
                    if (read_ptr >= (FRAME_SIZE*2 - 1))
                        read_ptr <= 10'd0;
                    else
                        read_ptr <= read_ptr + 10'd1;
                    
                    // Check if done
                    if (read_count == FRAME_SIZE - 1) begin
                        read_state <= READ_IDLE;
                    end else begin
                        read_count <= read_count + 9'd1;
                    end
                end
            endcase
        end
    end

endmodule