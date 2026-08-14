`timescale 1ns / 1ps
//==============================================================================
// FFT Bypass Shim
//
// Drop-in replacement for fft_core_v2 that skips the Xilinx FFT IP entirely.
// Passes the first 257 frame samples directly downstream as fake FFT bins
// (real = sample, imag = 0), drains the remaining 255 samples silently, then
// pulses frame_consumed. The downstream pipeline sees a valid 257-bin stream
// with correct handshake timing.
//
// Purpose: isolate the FFT from pipeline bring-up. If the rest of the chain
// (feature_extractor_v2 -> feature_averager -> inference) works with this
// shim, the FFT IP is the problem.
//
// Compile-time selection in top.v:
//   `define FFT_BYPASS   -> instantiates this module
//   (default)            -> instantiates fft_core_v2
//==============================================================================

module fft_bypass (
    input  wire        clk,
    input  wire        rst_n,

    // Matches fft_core_v2 exactly
    input  wire [15:0] frame_sample,
    input  wire        frame_sample_valid,
    output reg         frame_consumed,

    output reg  [31:0] fft_bin_data,
    output reg         fft_bin_valid,
    output reg         fft_bin_last,

    output wire        fft_ready,
    output wire        fft_data_ready,
    output reg         re_stream_req
);

    localparam FRAME_SIZE = 512;
    localparam NUM_BINS   = 257;  // bins 0..256 (DC through Nyquist)

    localparam STATE_IDLE  = 2'd0;
    localparam STATE_EMIT  = 2'd1;  // samples 0..256 -> emit as bins
    localparam STATE_DRAIN = 2'd2;  // samples 257..511 -> consume silently
    localparam STATE_DONE  = 2'd3;  // pulse frame_consumed, return to IDLE

    reg [1:0] state;
    reg [9:0] count;  // sample index within the current frame

    assign fft_ready      = (state == STATE_IDLE);
    assign fft_data_ready = 1'b1;  // always ready, no backpressure

    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            count          <= 10'd0;
            frame_consumed <= 1'b0;
            fft_bin_data   <= 32'd0;
            fft_bin_valid  <= 1'b0;
            fft_bin_last   <= 1'b0;
            re_stream_req  <= 1'b0;
        end else begin
            frame_consumed <= 1'b0;
            fft_bin_valid  <= 1'b0;
            fft_bin_last   <= 1'b0;
            re_stream_req  <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (frame_sample_valid) begin
                        // Capture bin 0 immediately — don't burn a cycle just transitioning.
                        // The stream is exactly 512 cycles; wasting one here causes a
                        // permanent deadlock where count reaches 511 with no valid left.
                        fft_bin_data  <= {frame_sample, 16'd0};
                        fft_bin_valid <= 1'b1;
                        fft_bin_last  <= 1'b0;  // NUM_BINS=257, so count=0 is never the last
                        count         <= 10'd1;
                        state         <= STATE_EMIT;
                    end else begin
                        count <= 10'd0;
                    end
                end

                STATE_EMIT: begin
                    if (frame_sample_valid) begin
                        fft_bin_data  <= {frame_sample, 16'd0};
                        fft_bin_valid <= 1'b1;
                        fft_bin_last  <= (count == NUM_BINS - 1);
                        count         <= count + 10'd1;
                        if (count == NUM_BINS - 1)
                            state <= STATE_DRAIN;
                    end
                end

                STATE_DRAIN: begin
                    // count enters here at 257; drain until sample 511 (index FRAME_SIZE-1)
                    if (frame_sample_valid) begin
                        if (count == FRAME_SIZE - 1)
                            state <= STATE_DONE;
                        else
                            count <= count + 10'd1;
                    end
                end

                STATE_DONE: begin
                    frame_consumed <= 1'b1;
                    state          <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
