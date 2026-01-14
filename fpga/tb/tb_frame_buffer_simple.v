// Simplified Frame Buffer Testbench
// Tests the fixed trigger logic: 511, 767, 1023, 255, 511...
// Date: January 14, 2026

`timescale 1ns / 1ps

module tb_frame_buffer_simple;
    
    reg clk, rst_n;
    reg [15:0] audio_sample;
    reg sample_valid;
    reg frame_consumed;
    wire frame_ready;
    wire [8191:0] frame_data_packed;
    
    // Instantiate DUT
    frame_buffer dut (
        .clk(clk),
        .rst_n(rst_n),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid),
        .frame_consumed(frame_consumed),
        .frame_ready(frame_ready),
        .frame_data_packed(frame_data_packed)
    );
    
    // Clock: 100 MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // VCD dump
    initial begin
        $dumpfile("tb_frame_buffer.vcd");
        $dumpvars(0, tb_frame_buffer_simple);
    end
    
    // Test
    integer i;
    integer frame_count;
    
    initial begin
        // Initialize
        rst_n = 0;
        audio_sample = 0;
        sample_valid = 0;
        frame_consumed = 0;
        frame_count = 0;
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("===========================================");
        $display("Frame Buffer Test - Fixed Trigger Logic");
        $display("Expected triggers: 511, 767, 1023, 1279, 1535...");
        $display("(Every 256 samples after first frame)");
        $display("===========================================\n");
        
        // Feed 2000 samples to get 5+ frames (511 + 4*256 = 1535 + margin)
        for (i = 0; i < 2000; i = i + 1) begin
            @(posedge clk);
            audio_sample = i[15:0];
            sample_valid = 1;
            
            // Debug output at key positions
            if (i == 255 || i == 511 || i == 767 || i == 1023 || i == 1279) begin
                $display("[Sample %4d] write_ptr=%0d, processing=%0d, buffer_filled=%0d", 
                         i, dut.write_ptr, dut.processing, dut.buffer_filled);
            end
            
            @(posedge clk);
            sample_valid = 0;
            
            // Check for frame ready
            if (frame_ready) begin
                frame_count = frame_count + 1;
                $display("[Sample %4d] Frame #%0d ready (write_ptr=%0d)", i, frame_count, dut.write_ptr);
                
                // Consume frame after a few cycles
                repeat(3) @(posedge clk);
                frame_consumed = 1;
                @(posedge clk);
                frame_consumed = 0;
                
                // Verify trigger spacing
                if (frame_count == 1 && i != 511) begin
                    $display("  ERROR: First frame should trigger at 511, got %d", i);
                end else if (frame_count >= 2) begin
                    // After first frame, should trigger every 256 samples
                    integer expected = 511 + (frame_count-1) * 256;
                    if (i != expected) begin
                        $display("  ERROR: Frame %0d should trigger at %0d, got %d", frame_count, expected, i);
                    end
                end
            end
        end
        
        $display("\n===========================================");
        $display("Test Complete!");
        $display("Total frames generated: %0d", frame_count);
        if (frame_count >= 5) begin
            $display("PASS: Frame buffer working correctly");
        end else begin
            $display("FAIL: Only got %0d frames (expected at least 5)", frame_count);
        end
        $display("===========================================");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #1000000; // 1ms timeout
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule
