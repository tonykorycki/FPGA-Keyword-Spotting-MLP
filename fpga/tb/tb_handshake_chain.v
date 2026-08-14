`timescale 1ns / 1ps
//==============================================================================
// tb_handshake_chain.v
//
// Targeted handshake testbench: frame_buffer -> fft_core_v2 -> feature_extractor_v2
//
// Verifies that all handshake signals propagate correctly through the pipeline
// WITHOUT requiring Vivado or the real xfft_0 IP.  Uses xfft_0_stub.v.
//
// Compile and run (Icarus Verilog, from fpga/ directory):
//   iverilog -g2012 -o sim/handshake_chain.vvp \
//       tb/tb_handshake_chain.v \
//       rtl/frame_buffer.v \
//       rtl/fft_core_v2.v \
//       rtl/feature_extractor_v2.v \
//       rtl/xfft_0_stub.v \
//     && vvp sim/handshake_chain.vvp
//
// View waveform:
//   gtkwave sim/handshake_chain.vcd
//
// Expected output (2 frames injected):
//   [PASS] frame_ready fired >= 2 times
//   [PASS] frame_consumed fired >= 2 times
//   [PASS] fft_bin_last fired >= 2 times
//   [PASS] features_valid fired >= 2 times
//==============================================================================

module tb_handshake_chain;

    //==========================================================================
    // Clock / Reset
    //==========================================================================
    reg clk, rst_n;
    initial begin clk = 0; forever #10 clk = ~clk; end  // 50 MHz = 20 ns period

    //==========================================================================
    // DUT Signal Declarations
    //==========================================================================

    // I2S-side inputs
    reg  [15:0] audio_sample;
    reg         sample_valid;

    // frame_buffer outputs to fft_core_v2
    wire        frame_ready;
    wire [15:0] frame_sample;
    wire        frame_sample_valid;

    // fft_core_v2 outputs
    wire        frame_consumed;       // fft_core_v2 -> frame_buffer
    wire [31:0] fft_bin_data;         // serial bin output [31:16]=real, [15:0]=imag
    wire        fft_bin_valid;        // bin data valid
    wire        fft_bin_last;         // last bin (bin 256) — replaces fft_done
    wire        fft_ready;            // fft_core_v2 -> frame_buffer (stream gate)
    wire        fft_data_ready;       // fft_core_v2 -> frame_buffer (backpressure)
    wire        re_stream_req;        // fft_core_v2 -> frame_buffer (recovery)

    // feature_extractor_v2 outputs
    wire        fft_consumed;         // feature_extractor_v2 -> (informational)
    wire [2055:0] features_packed;
    wire        features_valid;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    frame_buffer fb (
        .clk              (clk),
        .rst_n            (rst_n),
        .audio_sample     (audio_sample),
        .sample_valid     (sample_valid),
        .frame_consumed   (frame_consumed),
        .fft_ready        (fft_ready),
        .downstream_ready (fft_data_ready),
        .re_stream_req    (re_stream_req),
        .frame_ready      (frame_ready),
        .frame_sample     (frame_sample),
        .frame_sample_valid (frame_sample_valid)
    );

    fft_core_v2 fft (
        .clk              (clk),
        .rst_n            (rst_n),
        .frame_sample     (frame_sample),
        .frame_sample_valid (frame_sample_valid),
        .frame_consumed   (frame_consumed),
        .fft_bin_data     (fft_bin_data),
        .fft_bin_valid    (fft_bin_valid),
        .fft_bin_last     (fft_bin_last),
        .fft_ready        (fft_ready),
        .fft_data_ready   (fft_data_ready),
        .re_stream_req    (re_stream_req)
    );

    feature_extractor_v2 feat_ext (
        .clk              (clk),
        .rst_n            (rst_n),
        .fft_bin_data     (fft_bin_data),
        .fft_bin_valid    (fft_bin_valid),
        .fft_bin_last     (fft_bin_last),
        .fft_consumed     (fft_consumed),
        .features_packed  (features_packed),
        .features_valid   (features_valid)
    );

    //==========================================================================
    // VCD for GTKWave
    //==========================================================================
    initial begin
        $dumpfile("sim/handshake_chain.vcd");
        $dumpvars(0, tb_handshake_chain);
    end

    //==========================================================================
    // Handshake Event Counters
    //==========================================================================
    integer frame_ready_rise_count;
    integer frame_consumed_rise_count;
    integer fft_bin_last_rise_count;
    integer features_valid_rise_count;
    integer re_stream_rise_count;

    reg frame_ready_prev, frame_consumed_prev, fft_bin_last_prev, features_valid_prev;
    reg re_stream_prev;

    initial begin
        frame_ready_rise_count     = 0;
        frame_consumed_rise_count  = 0;
        fft_bin_last_rise_count    = 0;
        features_valid_rise_count  = 0;
        re_stream_rise_count       = 0;
        frame_ready_prev           = 0;
        frame_consumed_prev        = 0;
        fft_bin_last_prev          = 0;
        features_valid_prev        = 0;
        re_stream_prev             = 0;
    end

    always @(posedge clk) begin
        if (frame_ready && !frame_ready_prev) begin
            frame_ready_rise_count = frame_ready_rise_count + 1;
            $display("[%8t ns] frame_ready    ASSERTED  (count=%0d)", $time, frame_ready_rise_count);
        end
        if (!frame_ready && frame_ready_prev)
            $display("[%8t ns] frame_ready    deasserted -> frame consumed OK", $time);

        if (frame_consumed && !frame_consumed_prev) begin
            frame_consumed_rise_count = frame_consumed_rise_count + 1;
            $display("[%8t ns] frame_consumed PULSE     (count=%0d)", $time, frame_consumed_rise_count);
        end

        if (fft_bin_last && !fft_bin_last_prev) begin
            fft_bin_last_rise_count = fft_bin_last_rise_count + 1;
            $display("[%8t ns] fft_bin_last   PULSE     (count=%0d)", $time, fft_bin_last_rise_count);
        end

        if (features_valid && !features_valid_prev) begin
            features_valid_rise_count = features_valid_rise_count + 1;
            $display("[%8t ns] features_valid PULSE     (count=%0d)", $time, features_valid_rise_count);
            $display("           features[0]=%0d  features[10]=%0d  features[100]=%0d",
                     $signed(features_packed[7:0]),
                     $signed(features_packed[87:80]),
                     $signed(features_packed[807:800]));
        end

        if (re_stream_req && !re_stream_prev) begin
            re_stream_rise_count = re_stream_rise_count + 1;
            $display("[%8t ns] re_stream_req  PULSE     (count=%0d)", $time, re_stream_rise_count);
        end

        frame_ready_prev      <= frame_ready;
        frame_consumed_prev   <= frame_consumed;
        fft_bin_last_prev     <= fft_bin_last;
        features_valid_prev   <= features_valid;
        re_stream_prev        <= re_stream_req;
    end

    //==========================================================================
    // fft_ready monitoring — verify frame_buffer waits for it
    //==========================================================================
    integer stream_before_ready_count;
    initial stream_before_ready_count = 0;

    always @(posedge clk) begin
        if (frame_sample_valid && !fft_ready && fft.state == 3'd0) begin
            stream_before_ready_count = stream_before_ready_count + 1;
        end
    end

    //==========================================================================
    // Stimulus: inject FRAME_SIZE + FRAME_OVERLAP audio samples (covers 2 frames)
    //==========================================================================
    localparam SAMPLE_PERIOD = 10;    // cycles between sample_valid pulses
    localparam TOTAL_SAMPLES = 1024;  // enough for 2 full frames (512 + 512 overlap)

    integer i;
    integer fail_count;

    initial begin
        rst_n        = 1'b0;
        audio_sample = 16'h0000;
        sample_valid = 1'b0;
        fail_count   = 0;

        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        repeat (5)  @(posedge clk);

        $display("");
        $display("========================================");
        $display("  Handshake Chain Test (v2 serial)");
        $display("  frame_buffer -> fft_core_v2 -> feature_extractor_v2");
        $display("  Injecting %0d samples @ 1 per %0d cycles", TOTAL_SAMPLES, SAMPLE_PERIOD);
        $display("========================================");

        for (i = 0; i < TOTAL_SAMPLES; i = i + 1) begin
            @(posedge clk);
            audio_sample <= i[15:0];
            sample_valid <= 1'b1;
            @(posedge clk);
            sample_valid <= 1'b0;
            repeat (SAMPLE_PERIOD - 2) @(posedge clk);
        end

        // Wait up to 50000 cycles for both features_valid pulses to arrive
        begin : wait_features
            integer timeout;
            for (timeout = 0; timeout < 50000; timeout = timeout + 1) begin
                @(posedge clk);
                if (features_valid_rise_count >= 2) disable wait_features;
            end
        end

        repeat (200) @(posedge clk);

        //----------------------------------------------------------------------
        // Pass/Fail report
        //----------------------------------------------------------------------
        $display("");
        $display("========================================");
        $display("  Results");
        $display("========================================");

        if (frame_ready_rise_count >= 2)
            $display("[PASS] frame_ready fired %0d times (>= 2 expected)",
                     frame_ready_rise_count);
        else begin
            $display("[FAIL] frame_ready fired only %0d times -- frame buffer stuck?",
                     frame_ready_rise_count);
            fail_count = fail_count + 1;
        end

        if (frame_consumed_rise_count >= 2)
            $display("[PASS] frame_consumed fired %0d times (>= 2 expected)",
                     frame_consumed_rise_count);
        else begin
            $display("[FAIL] frame_consumed fired only %0d times -- fft_core_v2 stuck?",
                     frame_consumed_rise_count);
            fail_count = fail_count + 1;
        end

        if (fft_bin_last_rise_count >= 2)
            $display("[PASS] fft_bin_last fired %0d times (>= 2 expected)",
                     fft_bin_last_rise_count);
        else begin
            $display("[FAIL] fft_bin_last fired only %0d times -- FFT output stuck?",
                     fft_bin_last_rise_count);
            fail_count = fail_count + 1;
        end

        if (features_valid_rise_count >= 2)
            $display("[PASS] features_valid fired %0d times (>= 2 expected)",
                     features_valid_rise_count);
        else begin
            $display("[FAIL] features_valid fired only %0d times -- feature_extractor_v2 stuck?",
                     features_valid_rise_count);
            fail_count = fail_count + 1;
        end

        if (frame_ready_rise_count - frame_consumed_rise_count <= 1)
            $display("[PASS] No deadlock: frame_ready=%0d  frame_consumed=%0d  (delta <= 1 OK)",
                     frame_ready_rise_count, frame_consumed_rise_count);
        else begin
            $display("[FAIL] Deadlock: frame_ready=%0d >> frame_consumed=%0d (delta > 1)",
                     frame_ready_rise_count, frame_consumed_rise_count);
            fail_count = fail_count + 1;
        end

        if (stream_before_ready_count == 0)
            $display("[PASS] frame_buffer never streamed while fft_core_v2 not ready");
        else begin
            $display("[FAIL] frame_buffer streamed %0d cycles while fft_core_v2 in IDLE but not ready",
                     stream_before_ready_count);
            fail_count = fail_count + 1;
        end

        if (re_stream_rise_count == 0)
            $display("[PASS] re_stream_req never fired (no recovery needed)");
        else
            $display("[INFO] re_stream_req fired %0d times (recovery was triggered)",
                     re_stream_rise_count);

        $display("----------------------------------------");
        if (fail_count == 0)
            $display("  ALL CHECKS PASSED");
        else
            $display("  %0d CHECK(S) FAILED -- inspect VCD for details", fail_count);
        $display("========================================");
        $display("  VCD saved to sim/handshake_chain.vcd");
        $display("========================================");
        $finish;
    end

    //==========================================================================
    // Global timeout (2.5 ms sim time)
    //==========================================================================
    initial begin
        #2_500_000;
        $display("[TIMEOUT] Simulation exceeded 2.5 ms -- pipeline likely deadlocked.");
        $display("  frame_ready=%0d  frame_consumed=%0d  fft_bin_last=%0d  features_valid=%0d",
                 frame_ready_rise_count, frame_consumed_rise_count,
                 fft_bin_last_rise_count, features_valid_rise_count);
        $finish;
    end

endmodule
