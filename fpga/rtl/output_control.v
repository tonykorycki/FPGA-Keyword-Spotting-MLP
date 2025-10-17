// Output Control Module
// Manages output signals and LED display based on inference results
// Author: 
// Date: October 17, 2025

module output_control (
    input wire clk,                // System clock
    input wire rst_n,              // Active low reset
    input wire inference_done,     // Inference complete signal
    input wire inference_result,   // Inference result (1 = keyword detected)
    output reg [15:0] led,         // LED outputs for visualization
    output reg detected            // Keyword detection signal
);

    // Parameters
    parameter DETECTION_HOLD_CYCLES = 24'd5_000_000; // Hold detection for ~0.1s at 50 MHz
    
    // Internal registers
    reg [23:0] hold_counter;
    reg detection_active;
    
    // Visualization pattern for LEDs
    reg [15:0] led_pattern;
    reg [23:0] pattern_counter;
    
    // Output control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led <= 16'h0000;
            detected <= 1'b0;
            hold_counter <= 24'd0;
            detection_active <= 1'b0;
            led_pattern <= 16'h0000;
            pattern_counter <= 24'd0;
        end else begin
            // Check for new detection
            if (inference_done && inference_result) begin
                detection_active <= 1'b1;
                hold_counter <= DETECTION_HOLD_CYCLES;
                detected <= 1'b1;
                led_pattern <= 16'h8001; // Initialize LED pattern
            end
            
            // Handle active detection
            if (detection_active) begin
                if (hold_counter > 0) begin
                    hold_counter <= hold_counter - 24'd1;
                    
                    // Animate LEDs during detection
                    pattern_counter <= pattern_counter + 24'd1;
                    if (pattern_counter >= 24'd500_000) begin // Update pattern every ~10ms
                        pattern_counter <= 24'd0;
                        // Rotate pattern
                        led_pattern <= {led_pattern[0], led_pattern[15:1]};
                    end
                    led <= led_pattern;
                    
                end else begin
                    // End detection period
                    detection_active <= 1'b0;
                    detected <= 1'b0;
                    led <= 16'h0000;
                end
            end
        end
    end
    
endmodule