// I2S Receiver Module
// This module receives audio data from an I2S interface
// Author: 
// Date: October 17, 2025

module i2s_rx (
    input wire clk,              // System clock
    input wire rst_n,            // Active low reset
    input wire sdin,             // Serial data input
    input wire sclk,             // Serial clock input
    input wire lrclk,            // Left/Right clock input
    output reg [15:0] audio_sample, // Audio sample output
    output reg sample_valid      // Sample valid signal
);

    // I2S receive registers
    reg [15:0] shift_reg;
    reg sclk_prev, lrclk_prev;
    reg [4:0] bit_count;

    // Edge detection
    wire sclk_posedge = sclk && !sclk_prev;
    wire lrclk_change = lrclk != lrclk_prev;

    // I2S receiver logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'b0;
            audio_sample <= 16'b0;
            sample_valid <= 1'b0;
            sclk_prev <= 1'b0;
            lrclk_prev <= 1'b0;
            bit_count <= 5'd0;
        end else begin
            // Store previous states for edge detection
            sclk_prev <= sclk;
            lrclk_prev <= lrclk;
            
            // Reset sample_valid
            sample_valid <= 1'b0;
            
            // On SCLK rising edge, shift in data
            if (sclk_posedge) begin
                shift_reg <= {shift_reg[14:0], sdin};
                bit_count <= bit_count + 5'd1;
                
                // After 16 bits, we have a complete sample
                if (bit_count == 5'd15) begin
                    audio_sample <= {shift_reg[14:0], sdin};
                    sample_valid <= 1'b1;
                    bit_count <= 5'd0;
                end
            end
            
            // On LRCLK change (channel change), reset bit count
            if (lrclk_change) begin
                bit_count <= 5'd0;
            end
        end
    end

endmodule
