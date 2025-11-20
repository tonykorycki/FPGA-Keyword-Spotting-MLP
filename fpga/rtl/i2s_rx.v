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
    (* mark_debug = "true" *) output reg [15:0] audio_sample,  // Audio sample output
    (* mark_debug = "true" *) output reg sample_valid          // Sample valid signal
);

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
    // SPH0645 timing:
    // - Data valid on BCLK rising edge
    // - MSB first (bit 17 down to bit 0, 18-bit data)
    // - Left channel when LRCLK = LOW
    // - First data bit appears one BCLK cycle after LRCLK transition
    
    reg [31:0] shift_reg;
    reg lrclk_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 32'd0;
            audio_sample <= 16'd0;
            sample_valid <= 1'b0;
            lrclk_prev <= 1'b0;
        end else begin
            lrclk_prev <= lrclk_reg;
            sample_valid <= 1'b0;
            
            // Sample data on BCLK rising edge (when bclk_reg transitions from 0 to 1)
            if (bclk_div == 7'd0 && bclk_reg == 1'b0) begin
                shift_reg <= {shift_reg[30:0], i2s_dout};
            end
            
            // Capture left channel sample when LRCLK transitions from LOW to HIGH
            // This marks the end of left channel data
            if (lrclk_prev == 1'b0 && lrclk_reg == 1'b1) begin
                // SPH0645 has 18-bit data left-justified in 32-bit frame
                // Bits [31:14] contain the 18-bit audio data
                // Take bits [31:16] for 16-bit output (discard 2 LSBs)
                audio_sample <= shift_reg[31:16];
                sample_valid <= 1'b1;
            end
        end
    end

endmodule
