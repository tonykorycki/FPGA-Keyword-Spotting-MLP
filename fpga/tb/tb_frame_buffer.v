// Frame Buffer Testbench
// Author: 
// Date: October 17, 2025

`timescale 1ns / 1ps

module tb_frame_buffer;
    // Parameters
    localparam CLOCK_PERIOD = 10; // 100 MHz clock
    localparam FRAME_SIZE = 512;
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg [15:0] audio_sample;
    reg sample_valid;
    reg frame_consumed;
    wire frame_ready;
    wire [8191:0] frame_data_packed;  // 512 samples × 16 bits = 8192 bits
    
    // Unpacked frame data for easy access
    wire [15:0] frame_data [0:FRAME_SIZE-1];
    genvar g;
    generate
        for (g = 0; g < FRAME_SIZE; g = g + 1) begin : unpack_frame
            assign frame_data[g] = frame_data_packed[g*16 +: 16];
        end
    endgenerate
    
    // Instantiate the frame buffer module
    frame_buffer frame_buffer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid),
        .frame_consumed(frame_consumed),
        .frame_ready(frame_ready),
        .frame_data_packed(frame_data_packed)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    integer i, j;
    initial begin
        $dumpfile("tb_frame_buffer.vcd");
        $dumpvars(0, tb_frame_buffer);
        
        // Initialize
        rst_n = 0;
        audio_sample = 16'd0;
        sample_valid = 0;
        frame_consumed = 0;
        
        // Apply reset
        #(CLOCK_PERIOD*10);
        rst_n = 1;
        #(CLOCK_PERIOD*10);
        
        $display("===========================================");
        $display("Frame Buffer Testbench");
        $display("Target: 512 samples per frame, 50%% overlap");
        $display("===========================================");
        
        // Feed audio samples (need >768 for two frames with 50% overlap)
        for (i = 0; i < 1000; i = i + 1) begin
            // Generate ramp pattern for easy verification
            audio_sample = i[15:0]; // Use sample index as value
            sample_valid = 1;
            #(CLOCK_PERIOD);
            sample_valid = 0;
            #(CLOCK_PERIOD*9); // Simulate ~10kHz sample rate at 100MHz clock
            
            // Consume frame when ready
            if (frame_ready) begin
                $display("[%0t] Frame ready detected at sample %d", $time, i);
                // Print first few samples for verification
                $display("  First 4 samples: [0]=%d [1]=%d [2]=%d [3]=%d", 
                         frame_data[0], frame_data[1], frame_data[2], frame_data[3]);
                $display("  Last 4 samples: [508]=%d [509]=%d [510]=%d [511]=%d", 
                         frame_data[508], frame_data[509], frame_data[510], frame_data[511]);
                
                // Signal frame consumed after a few cycles
                repeat(5) @(posedge clk);
                frame_consumed = 1;
                @(posedge clk);
                frame_consumed = 0;
            end
        end
        
        $display("===========================================");
        $display("Test Complete!");
        $display("===========================================");
        
        // End simulation
        #(CLOCK_PERIOD*100);
        $finish;
    end
    
    // Monitor frame readiness
    always @(posedge clk) begin
        if (frame_ready) begin
            $display("Frame ready at %t ns", $time);
        end
    end

endmodule