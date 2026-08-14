`timescale 1ns / 1ps
//==============================================================================
// xfft_0_stub.v - Simulation stub for Xilinx xfft_0 FFT IP
//
// Mimics AXI-Stream protocol behavior WITHOUT actual FFT computation.
// - Accepts 512 input samples (always ready)
// - Outputs 257 complex bins after fixed latency
// - Bin data is deterministic dummy values (nonzero so log features work)
//
// Use for: iverilog simulation of fft_core.v handshake without Vivado.
// NOT for synthesis - add xfft_0_stub.v only to the sim filelist.
//==============================================================================

module xfft_0 (
    input  wire        aclk,

    // Config channel
    input  wire [7:0]  s_axis_config_tdata,
    input  wire        s_axis_config_tvalid,
    output wire        s_axis_config_tready,

    // Input data channel
    input  wire [31:0] s_axis_data_tdata,
    input  wire        s_axis_data_tvalid,
    output wire        s_axis_data_tready,
    input  wire        s_axis_data_tlast,

    // Output data channel (Real Time: no tready; Unscaled: no tuser/status)
    // 64-bit: real=[25:0], imag=[57:32]
    output reg  [63:0] m_axis_data_tdata,
    output reg         m_axis_data_tvalid,
    output reg         m_axis_data_tlast,

    // Event outputs
    output wire        event_frame_started,
    output wire        event_tlast_unexpected,
    output wire        event_tlast_missing,
    output wire        event_data_in_channel_halt
);

    // Always ready - pipelined streaming FFT holds tready during input
    assign s_axis_config_tready          = 1'b1;
    assign s_axis_data_tready            = 1'b1;

    // Unused event outputs
    assign event_frame_started           = 1'b0;
    assign event_tlast_unexpected        = 1'b0;
    assign event_tlast_missing           = 1'b0;
    assign event_data_in_channel_halt    = 1'b0;

    //--------------------------------------------------------------------------
    // Processing latency pipeline
    // Wait LATENCY_CYCLES after input tlast before streaming output.
    //--------------------------------------------------------------------------
    localparam LATENCY_CYCLES = 16;
    // fft_core collects bins 0..256 (257 bins), so output exactly 257 bins.
    // Asserting tlast on bin 256 causes fft_core to exit STATE_COLLECT cleanly.
    localparam OUTPUT_BINS = 257;

    reg [LATENCY_CYCLES-1:0] tlast_pipe;
    reg        out_active;
    reg [8:0]  out_counter;   // 0..256

    initial begin
        tlast_pipe         = {LATENCY_CYCLES{1'b0}};
        out_active         = 1'b0;
        out_counter        = 9'd0;
        m_axis_data_tdata  = 64'h0;
        m_axis_data_tvalid = 1'b0;
        m_axis_data_tlast  = 1'b0;
    end

    always @(posedge aclk) begin
        // Shift pipeline; inject 1 when input frame completes
        tlast_pipe <= {tlast_pipe[LATENCY_CYCLES-2:0],
                       s_axis_data_tvalid & s_axis_data_tlast};

        // Start output phase after latency
        if (tlast_pipe[LATENCY_CYCLES-1] && !out_active) begin
            out_active  <= 1'b1;
            out_counter <= 9'd0;
        end

        if (out_active) begin
            // Drive valid and deterministic nonzero bin data so log features
            // produce nonzero results.
            // 64-bit format: real=[25:0], imag=[57:32]. Pack nonzero values
            // in those fields; unused bits in each 32-bit half are zero.
            // real=512 (26-bit), imag=128 (26-bit)
            m_axis_data_tvalid <= 1'b1;
            m_axis_data_tdata  <= {6'b0, 26'd128, 6'b0, 26'd512};

            // Advance unconditionally each cycle (pipelined streaming mode -
            // consumer is always ready during output once tready goes high).
            // tlast on the last bin lets fft_core exit STATE_COLLECT.
            if (out_counter == OUTPUT_BINS - 1) begin
                m_axis_data_tlast <= 1'b1;
                out_active        <= 1'b0;
                out_counter       <= 9'd0;
            end else begin
                m_axis_data_tlast <= 1'b0;
                out_counter       <= out_counter + 9'd1;
            end
        end else begin
            // Deassert one cycle after tlast fires
            if (m_axis_data_tlast) begin
                m_axis_data_tvalid <= 1'b0;
                m_axis_data_tlast  <= 1'b0;
            end
        end
    end

endmodule
