// Quantized Math Operations Testbench
// Author: 
// Date: October 17, 2025

`timescale 1ns / 1ps

module tb_qmath;
    // Define test case parameters
    reg signed [7:0] a, b;
    reg signed [15:0] result_mul;
    reg signed [7:0] result_add;
    
    // Test cases
    initial begin
        // Test case for multiplication
        $display("Testing quantized multiplication");
        a = 8'sd40;  // 40/128 = 0.3125
        b = 8'sd60;  // 60/128 = 0.46875
        // Expected result: 0.3125 * 0.46875 = 0.146484375
        // In Q8 format: 0.146484375 * 256 = ~37.5
        // In Q7.8 format: ~9600
        result_mul = a * b;
        $display("a=%d, b=%d, a*b=%d (should be near 2400)", a, b, result_mul);
        
        // Test case for addition
        $display("Testing quantized addition");
        a = 8'sd40;  // 40/128 = 0.3125
        b = 8'sd60;  // 60/128 = 0.46875
        // Expected result: 0.3125 + 0.46875 = 0.78125
        // In Q8 format: 0.78125 * 128 = 100
        result_add = a + b;
        $display("a=%d, b=%d, a+b=%d (should be 100)", a, b, result_add);
        
        // Test case for negative numbers
        $display("Testing with negative numbers");
        a = -8'sd40;  // -0.3125
        b = 8'sd60;   // 0.46875
        result_mul = a * b;
        $display("a=%d, b=%d, a*b=%d (should be near -2400)", a, b, result_mul);
        
        result_add = a + b;
        $display("a=%d, b=%d, a+b=%d (should be 20)", a, b, result_add);
        
        // Test case for overflow
        $display("Testing potential overflow");
        a = 8'sd100;  // 100/128 = 0.78125
        b = 8'sd100;  // 100/128 = 0.78125
        result_mul = a * b;
        $display("a=%d, b=%d, a*b=%d (should be 10000, showing overflow behavior)", a, b, result_mul);
        
        // Saturating addition example
        $display("Testing saturating addition");
        a = 8'sd100;
        b = 8'sd100;
        // Without saturation, this would overflow in 8 bits
        result_add = a + b > 127 ? 127 : (a + b < -128 ? -128 : a + b);
        $display("a=%d, b=%d, saturated a+b=%d (should be 127)", a, b, result_add);
        
        $finish;
    end
endmodule