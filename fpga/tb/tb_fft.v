// FFT Module Testbench
// Author: 
// Date: October 17, 2025

`timescale 1ns / 1ps

module tb_fft;
    // Parameters
    localparam FFT_POINTS = 256;
    localparam DATA_WIDTH = 16;
    localparam CLOCK_PERIOD = 10; // 100 MHz clock
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg start;
    reg [DATA_WIDTH-1:0] x_real [0:FFT_POINTS-1];
    reg [DATA_WIDTH-1:0] x_imag [0:FFT_POINTS-1];
    wire done;
    wire [DATA_WIDTH-1:0] y_real [0:FFT_POINTS-1];
    wire [DATA_WIDTH-1:0] y_imag [0:FFT_POINTS-1];
    
    // Instantiate the FFT core
    fft_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .FFT_POINTS(FFT_POINTS),
        .TWIDDLE_WIDTH(16)
    ) fft_core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .x_real(x_real),
        .x_imag(x_imag),
        .done(done),
        .y_real(y_real),
        .y_imag(y_imag)
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
        start = 0;
        
        // Initialize input data to zeros
        for (integer i = 0; i < FFT_POINTS; i++) begin
            x_real[i] = 16'd0;
            x_imag[i] = 16'd0;
        end
        
        // Apply reset
        #(CLOCK_PERIOD*10);
        rst_n = 1;
        #(CLOCK_PERIOD*10);
        
        // Generate sine wave input
        for (integer i = 0; i < FFT_POINTS; i++) begin
            // Simple sine wave at frequency bin 4
            x_real[i] = $rtoi($sin(2*3.14159*4*i/FFT_POINTS) * 32767);
            x_imag[i] = 16'd0;
        end
        
        // Start FFT computation
        start = 1;
        #(CLOCK_PERIOD);
        start = 0;
        
        // Wait for FFT to complete
        @(posedge done);
        #(CLOCK_PERIOD*10);
        
        // Display results (just a subset for verification)
        $display("FFT Results (first 16 bins):");
        for (integer i = 0; i < 16; i++) begin
            $display("Bin %d: Real = %d, Imag = %d", i, y_real[i], y_imag[i]);
        end
        
        // End simulation
        $finish;
    end
    
    // Monitor FFT progress
    always @(posedge clk) begin
        if (done) begin
            $display("FFT computation complete at %t ns", $time);
        end
    end

endmodule