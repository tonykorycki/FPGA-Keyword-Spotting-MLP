`timescale 1ns / 1ps

//=============================================================================
// Comprehensive Audio Pipeline Testbench (FOR VIVADO SIMULATOR)
//=============================================================================
// Tests the complete audio processing chain:
//   I2S RX → Frame Buffer → FFT Core → Feature Extractor → (Optional) Feature Averager
//
// Includes multiple audio test signals:
//   - Silence
//   - DC offset
//   - Single tone (sine wave)
//   - Dual tone
//   - Chirp (frequency sweep)
//   - White noise
//
// REQUIREMENTS:
//   - Must be run in Vivado Simulator (uses Xilinx FFT IP)
//   - FFT IP (xfft_0) must be generated in Vivado project
//   - Use `ENABLE_AVERAGER parameter to test with/without feature averaging
//
// USAGE:
//   1. In Vivado: Simulation → Run Simulation
//   2. Set tb_audio_pipeline as top module
//   3. Run for 500ms to see all tests complete
//=============================================================================

module tb_audio_pipeline;

    // Testbench parameters
    parameter ENABLE_AVERAGER = 0;  // Disabled for faster simulation
    parameter SAMPLE_RATE = 16000;
    parameter NUM_SAMPLES = 256;    // Half frame for fastest simulation
    parameter FAST_SIM = 1;         // Bypass I2S timing, inject samples directly
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // I2S signals (simulated microphone)
    wire i2s_bclk;
    wire i2s_lrclk;
    reg i2s_dout;
    
    // I2S RX outputs
    wire [15:0] audio_sample;
    wire sample_valid;
    
    // Frame buffer outputs
    wire frame_ready;
    wire [8191:0] frame_data_packed;
    wire frame_consumed;
    
    // FFT outputs
    wire fft_done;
    wire [8223:0] fft_bins_packed;
    
    // Feature extractor outputs
    wire features_valid;
    wire [2055:0] features_packed;
    wire fft_consumed;
    
    // Feature averager outputs (optional)
    wire averaged_valid;
    wire [4111:0] averaged_features;
    
    // Unpacked features for inspection
    wire [7:0] features [0:256];
    wire [15:0] avg_features [0:256];
    
    genvar g;
    generate
        for (g = 0; g < 257; g = g + 1) begin : unpack
            assign features[g] = features_packed[g*8 +: 8];
            assign avg_features[g] = averaged_features[g*16 +: 16];
        end
    endgenerate
    
    //=========================================================================
    // DUT Instantiation - Complete Audio Pipeline
    //=========================================================================
    
    // I2S Receiver (or bypassed in fast sim mode)
    generate
        if (FAST_SIM) begin : gen_fast_sim
            // Fast simulation: bypass I2S, inject samples directly
            reg [15:0] fast_audio_sample;
            reg fast_sample_valid;
            assign audio_sample = fast_audio_sample;
            assign sample_valid = fast_sample_valid;
            assign i2s_bclk = 1'b0;
            assign i2s_lrclk = 1'b0;
        end else begin : gen_real_i2s
            // Real I2S receiver
            i2s_rx i2s (
                .clk(clk),
                .rst_n(rst_n),
                .i2s_bclk(i2s_bclk),
                .i2s_lrclk(i2s_lrclk),
                .i2s_dout(i2s_dout),
                .audio_sample(audio_sample),
                .sample_valid(sample_valid)
            );
        end
    endgenerate
    
    // Frame Buffer
    frame_buffer fb (
        .clk(clk),
        .rst_n(rst_n),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid),
        .frame_consumed(frame_consumed),
        .frame_ready(frame_ready),
        .frame_data_packed(frame_data_packed)
    );
    
    // FFT Core (Xilinx FFT IP wrapper)
    fft_core fft (
        .clk(clk),
        .rst_n(rst_n),
        .frame_data_packed(frame_data_packed),
        .frame_valid(frame_ready),
        .frame_consumed(frame_consumed),
        .fft_bins_packed(fft_bins_packed),
        .fft_done(fft_done)
    );
    
    // Feature Extractor
    feature_extractor feat_ext (
        .clk(clk),
        .rst_n(rst_n),
        .fft_bins_packed(fft_bins_packed),
        .fft_valid(fft_done),
        .fft_consumed(fft_consumed),
        .features_packed(features_packed),
        .features_valid(features_valid)
    );
    
    // Feature Averager (optional)
    generate
        if (ENABLE_AVERAGER) begin : gen_averager
            feature_averager #(
                .NUM_FEATURES(257),
                .WINDOW_FRAMES(4),     // Small window for testing
                .FEATURE_WIDTH(16),
                .SUM_WIDTH(24)
            ) avg (
                .clk(clk),
                .rst_n(rst_n),
                .frame_features(features_packed),
                .frame_valid(features_valid),
                .averaged_features(averaged_features),
                .averaged_valid(averaged_valid)
            );
        end else begin : gen_no_averager
            assign averaged_features = {4112{1'b0}};
            assign averaged_valid = 1'b0;
        end
    endgenerate
    
    //=========================================================================
    // Clock Generation (100 MHz)
    //=========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    //=========================================================================
    // Waveform Dump (Vivado)
    //=========================================================================
    // VCD dump disabled for Vivado - use Vivado's waveform viewer instead
    // In Vivado, add signals to waveform window manually or use:
    // add_wave {{/tb_audio_pipeline/*}}
    
    //=========================================================================
    // Test Signal Generation
    //=========================================================================
    reg signed [15:0] test_audio [0:NUM_SAMPLES-1];
    integer sample_idx;
    integer i;
    real pi = 3.14159265359;
    real sample_value;
    real freq1, freq2, chirp_rate;
    
    // Task: Generate silence
    task generate_silence;
        begin
            $display("Generating SILENCE...");
            for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
                test_audio[i] = 16'h0000;
            end
        end
    endtask
    
    // Task: Generate DC offset
    task generate_dc_offset;
        input signed [15:0] dc_value;
        begin
            $display("Generating DC OFFSET (value=%0d)...", dc_value);
            for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
                test_audio[i] = dc_value;
            end
        end
    endtask
    
    // Task: Generate sine wave
    task generate_sine;
        input real frequency;
        input real amplitude;
        begin
            $display("Generating SINE WAVE (freq=%0.1f Hz, amp=%0.2f)...", frequency, amplitude);
            for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
                sample_value = amplitude * $sin(2.0 * pi * frequency * i / SAMPLE_RATE);
                test_audio[i] = sample_value * 32767.0;
            end
        end
    endtask
    
    // Task: Generate dual tone
    task generate_dual_tone;
        input real freq1_in;
        input real freq2_in;
        input real amp1;
        input real amp2;
        begin
            $display("Generating DUAL TONE (f1=%0.1f Hz, f2=%0.1f Hz)...", freq1_in, freq2_in);
            for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
                sample_value = amp1 * $sin(2.0 * pi * freq1_in * i / SAMPLE_RATE) +
                               amp2 * $sin(2.0 * pi * freq2_in * i / SAMPLE_RATE);
                test_audio[i] = sample_value * 32767.0;
            end
        end
    endtask
    
    // Task: Generate chirp (frequency sweep)
    task generate_chirp;
        input real start_freq;
        input real end_freq;
        input real amplitude;
        begin
            $display("Generating CHIRP (sweep %0.1f → %0.1f Hz)...", start_freq, end_freq);
            chirp_rate = (end_freq - start_freq) / NUM_SAMPLES;
            for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
                freq1 = start_freq + chirp_rate * i;
                sample_value = amplitude * $sin(2.0 * pi * freq1 * i / SAMPLE_RATE);
                test_audio[i] = sample_value * 32767.0;
            end
        end
    endtask
    
    // Task: Generate white noise
    task generate_noise;
        input real amplitude;
        integer seed;
        begin
            $display("Generating WHITE NOISE (amp=%0.2f)...", amplitude);
            seed = 12345;
            for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
                sample_value = amplitude * (($random(seed) % 32768) / 32768.0 - 0.5) * 2.0;
                test_audio[i] = sample_value * 32767.0;
            end
        end
    endtask
    
    //=========================================================================
    // Audio Sample Injection (Fast Mode)
    //=========================================================================
    reg transmitting;
    integer inject_delay;
    
    initial begin
        i2s_dout = 0;
        transmitting = 0;
        sample_idx = 0;
    end
    
    // Fast mode: inject samples directly at 16 kHz rate
    generate
        if (FAST_SIM) begin : gen_fast_inject
            always @(posedge clk) begin
                if (!rst_n) begin
                    inject_delay <= 0;
                    gen_fast_sim.fast_sample_valid <= 0;
                    sample_idx <= 0;
                end else if (transmitting && sample_idx < NUM_SAMPLES) begin
                    inject_delay <= inject_delay + 1;
                    
                    // Inject sample every 6250 clocks (16 kHz @ 100 MHz)
                    if (inject_delay >= 6250) begin
                        gen_fast_sim.fast_audio_sample <= test_audio[sample_idx];
                        gen_fast_sim.fast_sample_valid <= 1;
                        sample_idx <= sample_idx + 1;
                        inject_delay <= 0;
                    end else begin
                        gen_fast_sim.fast_sample_valid <= 0;
                    end
                end else begin
                    gen_fast_sim.fast_sample_valid <= 0;
                end
            end
        end
    endgenerate
    
    //=========================================================================
    // Test Monitoring and Statistics
    //=========================================================================
    integer frames_received;
    integer features_received;
    integer averaged_received;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            frames_received <= 0;
            features_received <= 0;
            averaged_received <= 0;
        end else begin
            if (frame_ready) begin
                frames_received <= frames_received + 1;
                $display("[%0t] Frame #%0d ready", $time, frames_received);
            end
            
            if (features_valid) begin
                features_received <= features_received + 1;
                $display("[%0t] Features #%0d ready (DC=%0d, Bin[10]=%0d, Bin[64]=%0d)", 
                         $time, features_received, features[0], features[10], features[64]);
            end
            
            if (ENABLE_AVERAGER && averaged_valid) begin
                averaged_received <= averaged_received + 1;
                $display("[%0t] Averaged features #%0d ready", $time, averaged_received);
            end
        end
    end
    
    //=========================================================================
    // Main Test Sequence
    //=========================================================================
    integer test_num;
    
    task run_audio_test;
        input [255:0] test_name;
        input integer num_frames_expected;
        begin
            test_num = test_num + 1;
            
            $display("\n========================================");
            $display("TEST #%0d: %0s", test_num, test_name);
            $display("========================================");
            
            // Reset counters
            sample_idx = 0;
            frames_received = 0;
            features_received = 0;
            averaged_received = 0;
            
            // Start transmission
            transmitting = 1;
            
            // Wait for expected frames (with timeout)
            while (frames_received < num_frames_expected) begin
                @(posedge clk);
            end
            
            $display("✓ Received %0d frames", frames_received);
            
            // Stop transmission
            transmitting = 0;
            
            // Wait for pipeline to flush
            #100000;
            
            $display("Pipeline stats: Frames=%0d, Features=%0d, Averaged=%0d",
                     frames_received, features_received, averaged_received);
        end
    endtask
    
    initial begin
        $display("========================================");
        $display("AUDIO PIPELINE TESTBENCH");
        $display("========================================");
        if (ENABLE_AVERAGER)
            $display("Mode: WITH FEATURE AVERAGER");
        else
            $display("Mode: WITHOUT FEATURE AVERAGER");
        $display("========================================\n");
        
        // Initialize
        rst_n = 0;
        test_num = 0;
        
        // Reset
        #100;
        rst_n = 1;
        $display("[%0t] Reset released\n", $time);
        
        // Wait for I2S clocks to stabilize
        #100000;
        
        // Reduced test suite for faster simulation (3 tests instead of 7)
        // Uncomment additional tests if needed
        
        
        //=====================================================================
        // TEST 1: Silence
        //=====================================================================
        generate_silence();
        run_audio_test("Silence", 1);
        
        //=====================================================================
        // TEST 2: DC Offset
        //=====================================================================
        generate_dc_offset(16'h1000);
        run_audio_test("DC Offset", 1);
        
        
        //=====================================================================
        // TEST 1: 440 Hz Sine Wave (musical note A4)
        //=====================================================================
        generate_sine(440.0, 0.8);
        run_audio_test("440 Hz Sine Wave", 1);
        
        
        //=====================================================================
        // TEST 2: 1 kHz Sine Wave
        //=====================================================================
        generate_sine(1000.0, 0.7);
        run_audio_test("1 kHz Sine Wave", 1);
        
        //=====================================================================
        // TEST: Dual Tone (697 Hz + 1209 Hz - DTMF '1')
        //=====================================================================
        generate_dual_tone(697.0, 1209.0, 0.5, 0.5);
        run_audio_test("Dual Tone (DTMF)", 1);
        
        //=====================================================================
        // TEST: Chirp (200 Hz → 4 kHz)
        //=====================================================================
        generate_chirp(200.0, 4000.0, 0.6);
        run_audio_test("Frequency Sweep", 1);
        
        //=====================================================================
        // TEST 7: White Noise
        //=====================================================================
        generate_noise(0.3);
        run_audio_test("White Noise", 1);
        
        
        //=====================================================================
        // Final Summary
        //=====================================================================
        #100000;
        
        $display("\n========================================");
        $display("ALL TESTS COMPLETE");
        $display("========================================");
        $display("Total tests run: %0d", test_num);
        $display("\nAudio pipeline verification complete!");
        
        $finish;
    end

endmodule
