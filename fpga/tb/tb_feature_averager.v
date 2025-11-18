`timescale 1ns / 1ps
//=============================================================================
// Feature Averager Testbench
//=============================================================================

module tb_feature_averager;

    parameter NUM_FEATURES = 257;
    parameter WINDOW_FRAMES = 31;
    parameter FEATURE_WIDTH = 16;
    parameter SUM_WIDTH = 24;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // DUT signals
    reg signed [FEATURE_WIDTH-1:0] frame_features_unpacked [0:NUM_FEATURES-1];
    reg [NUM_FEATURES*FEATURE_WIDTH-1:0] frame_features;
    reg frame_valid;
    wire [NUM_FEATURES*FEATURE_WIDTH-1:0] averaged_features;
    wire averaged_valid;
    
    // Pack frame features for DUT input
    integer pack_idx;
    always @(*) begin
        for (pack_idx = 0; pack_idx < NUM_FEATURES; pack_idx = pack_idx + 1) begin
            frame_features[pack_idx*FEATURE_WIDTH +: FEATURE_WIDTH] = frame_features_unpacked[pack_idx];
        end
    end
    
    // Unpack averaged features from DUT output
    wire signed [FEATURE_WIDTH-1:0] averaged_features_unpacked [0:NUM_FEATURES-1];
    genvar unpack_idx;
    generate
        for (unpack_idx = 0; unpack_idx < NUM_FEATURES; unpack_idx = unpack_idx + 1) begin : unpack_avg
            assign averaged_features_unpacked[unpack_idx] = averaged_features[unpack_idx*FEATURE_WIDTH +: FEATURE_WIDTH];
        end
    endgenerate
    
    // Instantiate DUT
    feature_averager #(
        .NUM_FEATURES(NUM_FEATURES),
        .WINDOW_FRAMES(WINDOW_FRAMES),
        .FEATURE_WIDTH(FEATURE_WIDTH),
        .SUM_WIDTH(SUM_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .frame_features(frame_features),
        .frame_valid(frame_valid),
        .averaged_features(averaged_features),
        .averaged_valid(averaged_valid)
    );
    
    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test stimulus
    integer i, frame_num;
    integer expected_avg;
    
    initial begin
        $display("=== Feature Averager Testbench ===");
        
        // Initialize
        rst_n = 0;
        frame_valid = 0;
        for (i = 0; i < NUM_FEATURES; i = i + 1) begin
            frame_features_unpacked[i] = 0;
        end
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 1: Send constant value frames
        $display("\n--- Test 1: Constant value (100) across frames ---");
        for (frame_num = 0; frame_num < 50; frame_num = frame_num + 1) begin
            @(posedge clk);
            frame_valid = 1;
            for (i = 0; i < NUM_FEATURES; i = i + 1) begin
                frame_features_unpacked[i] = 100;  // Constant value
            end
            @(posedge clk);
            frame_valid = 0;
            
            // Check output after warmup
            if (averaged_valid) begin
                $display("Frame %0d: avg[0] = %0d (expected ~100)", 
                         frame_num, averaged_features_unpacked[0]);
            end
            
            repeat(10) @(posedge clk);  // Simulate 32ms between frames
        end
        
        // Test 2: Increasing values
        $display("\n--- Test 2: Linearly increasing values ---");
        for (frame_num = 0; frame_num < 50; frame_num = frame_num + 1) begin
            @(posedge clk);
            frame_valid = 1;
            for (i = 0; i < NUM_FEATURES; i = i + 1) begin
                frame_features_unpacked[i] = frame_num * 2;  // Increases with frame
            end
            @(posedge clk);
            frame_valid = 0;
            
            if (averaged_valid) begin
                $display("Frame %0d: input=%0d, avg[0]=%0d", 
                         frame_num, frame_num*2, averaged_features_unpacked[0]);
            end
            
            repeat(10) @(posedge clk);
        end
        
        // Test 3: Step change (tests sliding window)
        $display("\n--- Test 3: Step change (0 -> 200) ---");
        for (frame_num = 0; frame_num < 70; frame_num = frame_num + 1) begin
            @(posedge clk);
            frame_valid = 1;
            for (i = 0; i < NUM_FEATURES; i = i + 1) begin
                frame_features_unpacked[i] = (frame_num < 35) ? 0 : 200;
            end
            @(posedge clk);
            frame_valid = 0;
            
            if (averaged_valid) begin
                $display("Frame %0d: input=%0d, avg[0]=%0d", 
                         frame_num, (frame_num < 35) ? 0 : 200, averaged_features_unpacked[0]);
            end
            
            repeat(10) @(posedge clk);
        end
        
        $display("\n=== Test Complete ===");
        $finish;
    end
    
    // Optional: Dump waveforms
    initial begin
        $dumpfile("tb_feature_averager.vcd");
        $dumpvars(0, tb_feature_averager);
    end

endmodule
