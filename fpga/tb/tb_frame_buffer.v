// Frame Buffer Testbench
// Author: 
// Date: October 17, 2025

`timescale 1ns / 1ps

module tb_frame_buffer;
    // Parameters
    localparam CLOCK_PERIOD = 10; // 100 MHz clock
    localparam FRAME_SIZE = 256;
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg [15:0] audio_sample;
    reg sample_valid;
    wire frame_ready;
    wire [15:0] frame_data [0:FRAME_SIZE-1];
    
    // Instantiate the frame buffer module
    frame_buffer frame_buffer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .audio_sample(audio_sample),
        .sample_valid(sample_valid),
        .frame_ready(frame_ready),
        .frame_data(frame_data)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize
        rst_n = 0;
        audio_sample = 16'd0;
        sample_valid = 0;
        
        // Apply reset
        #(CLOCK_PERIOD*10);
        rst_n = 1;
        #(CLOCK_PERIOD*10);
        
        // Feed audio samples
        for (integer i = 0; i < 500; i++) begin
            // Generate ramp pattern for easy verification
            audio_sample = (i % 256) << 8; // Scale up to use upper bits
            sample_valid = 1;
            #(CLOCK_PERIOD);
            sample_valid = 0;
            #(CLOCK_PERIOD*9); // Simulate 10kHz sample rate at 100MHz clock
            
            // Check if frame is ready
            if (frame_ready) begin
                $display("Frame ready detected at sample %d", i);
                // Print some frame data for verification
                for (integer j = 0; j < 10; j++) begin
                    $display("Frame data[%d] = %d", j, frame_data[j]);
                end
            end
        end
        
        // End simulation
        $finish;
    end
    
    // Monitor frame readiness
    always @(posedge clk) begin
        if (frame_ready) begin
            $display("Frame ready at %t ns", $time);
        end
    end

endmodule