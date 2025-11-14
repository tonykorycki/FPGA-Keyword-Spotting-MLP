// I2S Master Receiver Module for SPH0645
// This module generates I2S clocks and receives audio data from SPH0645
// SPH0645 is a slave-mode device - FPGA generates BCLK and LRCLK
// Author: FPGA KWS Project
// Date: November 14, 2025

module i2s_rx (
    input wire clk,                  // System clock (100 MHz)
    input wire rst_n,                // Active low reset
    
    // I2S Interface (to SPH0645)
    output wire i2s_bclk,            // Bit clock to mic (~1 MHz)
    output wire i2s_lrclk,           // LR clock to mic (~16 kHz)
    input wire i2s_dout,             // Data from mic
    
    // Output Interface
    (* mark_debug = "true" *) output reg [15:0] audio_sample,  // Audio sample output (DC removed)
    (* mark_debug = "true" *) output reg sample_valid          // Sample valid signal
);

    //=========================================================================
    // DC Offset Removal (High-Pass Filter)
    //=========================================================================
    // Simple 1st order IIR high-pass filter: y[n] = alpha * (y[n-1] + x[n] - x[n-1])
    // where alpha = 0.99 (DC blocking, cutoff ~25 Hz at 16kHz sample rate)
    
    parameter ALPHA_SHIFT = 7;  // alpha = 1 - 1/128 = 0.9922 (close to 0.99)
    
    reg signed [15:0] raw_sample;
    reg signed [15:0] prev_raw_sample;
    reg signed [31:0] dc_accumulator;
    wire signed [31:0] dc_removed;
    
    // DC removal: output = input - running average
    assign dc_removed = {raw_sample, 16'd0} - dc_accumulator;

    //=========================================================================
    // Clock Generation for 16 kHz Sample Rate
    //=========================================================================
    // BCLK = 16kHz * 64 = 1.024 MHz (32 bits per channel, 2 channels)
    // From 100MHz: divide by 98 gives ~1.02 MHz
    
    reg [6:0] bclk_div;
    reg bclk_reg;
    reg [5:0] bit_counter;
    reg lrclk_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bclk_div <= 7'd0;
            bclk_reg <= 1'b0;
            bit_counter <= 6'd0;
            lrclk_reg <= 1'b0;
        end else begin
            // Generate BCLK (~1 MHz)
            if (bclk_div >= 7'd48) begin
                bclk_div <= 7'd0;
                bclk_reg <= ~bclk_reg;
                
                // On rising edge of BCLK, count bits
                if (bclk_reg == 1'b0) begin
                    if (bit_counter >= 6'd63) begin
                        bit_counter <= 6'd0;
                    end else begin
                        bit_counter <= bit_counter + 6'd1;
                    end
                    
                    // Toggle LRCLK every 32 bits (left/right channel)
                    if (bit_counter == 6'd31 || bit_counter == 6'd63) begin
                        lrclk_reg <= ~lrclk_reg;
                    end
                end
            end else begin
                bclk_div <= bclk_div + 7'd1;
            end
        end
    end
    
    assign i2s_bclk = bclk_reg;
    assign i2s_lrclk = lrclk_reg;
    
    //=========================================================================
    // I2S Data Reception (Left Channel Only)
    //=========================================================================
    reg [31:0] shift_reg;
    reg lrclk_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 32'd0;
            raw_sample <= 16'd0;
            prev_raw_sample <= 16'd0;
            dc_accumulator <= 32'd0;
            audio_sample <= 16'd0;
            sample_valid <= 1'b0;
            lrclk_prev <= 1'b0;
        end else begin
            lrclk_prev <= lrclk_reg;
            sample_valid <= 1'b0;
            
            // Shift data on BCLK falling edge
            if (bclk_div == 7'd48 && bclk_reg == 1'b1) begin
                shift_reg <= {shift_reg[30:0], i2s_dout};
                
                // When we finish 32 bits of left channel (LRCLK was low)
                if (bit_counter == 6'd31 && lrclk_prev == 1'b0) begin
                    // SPH0645 gives 18-bit data in upper bits, take [31:16]
                    raw_sample <= shift_reg[31:16];
                    
                    // Update DC blocking filter
                    // Exponential moving average: dc_acc = dc_acc - dc_acc/128 + raw_sample
                    dc_accumulator <= dc_accumulator - (dc_accumulator >>> ALPHA_SHIFT) + {raw_sample, 16'd0};
                    
                    // Output DC-removed sample (scaled back down)
                    audio_sample <= dc_removed[31:16];
                    sample_valid <= 1'b1;
                end
            end
        end
    end

endmodule
