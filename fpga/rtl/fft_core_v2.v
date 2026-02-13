//=============================================================================
// FFT Core Wrapper V2 - Serial Bin Output (NOT ROUTED)
//=============================================================================
// Alternative to fft_core.v that outputs FFT bins serially (one per cycle)
// instead of packing all 257 bins into an 8224-bit vector.
//
// Benefits over original:
//   - Eliminates 257-element bin_real[], bin_imag[] storage arrays
//   - Eliminates 8224-bit combinational packing logic
//   - Reduces fanout and MUX congestion in downstream feature_extractor
//   - Pairs with feature_extractor_v2.v for full serial datapath
//
// To integrate:
//   1. Replace fft_core instantiation in top.v with this module
//   2. Update port connections:
//      - Remove: fft_bins_packed[8223:0]
//      - Add: fft_bin_data[31:0], fft_bin_valid, fft_bin_last
//   3. Replace feature_extractor with feature_extractor_v2
//   4. Wire new serial bin interface between fft_core_v2 and feature_extractor_v2
//
// Input:  512 real samples (serial, 1 per cycle)
// Output: 257 complex bins (serial, 1 per cycle, [31:16]=real, [15:0]=imag)
//
// Author: Tony Korycki
// Date: February 13, 2026
//=============================================================================

module fft_core_v2 (
    input  wire        clk,                      // System clock (50 MHz)
    input  wire        rst_n,                    // Active low reset
    
    // Input interface - serial samples
    input  wire [15:0] frame_sample,             // One sample per cycle
    input  wire        frame_sample_valid,       // Sample valid signal
    output reg         frame_consumed,           // Frame has been consumed
    
    // Output interface - serial FFT bins
    output reg [31:0]  fft_bin_data,             // One bin per cycle: [31:16]=real, [15:0]=imag
    output reg         fft_bin_valid,            // Bin data valid this cycle
    output reg         fft_bin_last              // Marks last bin (bin 256)
);

    //=========================================================================
    // State Machine
    //=========================================================================
    localparam STATE_IDLE        = 3'd0;
    localparam STATE_STREAM_IN   = 3'd1;
    localparam STATE_WAIT_OUTPUT = 3'd2;
    localparam STATE_STREAM_OUT  = 3'd3;
    localparam STATE_DONE        = 3'd4;
    
    reg [2:0] state;
    reg [9:0] sample_counter;  // 0-511 for input, 0-256 for output
    
    //=========================================================================
    // FFT IP AXI-Stream Signals
    //=========================================================================
    
    // Configuration channel (static - forward FFT, no transform length change)
    reg         config_tvalid;
    wire        config_tready;
    wire [7:0]  config_tdata = 8'h01;  // Forward FFT
    reg         config_done;
    
    // Input data channel
    reg         data_in_tvalid;
    wire        data_in_tready;
    reg [31:0]  data_in_tdata;
    reg         data_in_tlast;
    
    // Output data channel
    wire        data_out_tvalid;
    reg         data_out_tready;
    wire [31:0] data_out_tdata;
    wire [7:0]  data_out_tuser;  // Block floating point scale factor
    wire        data_out_tlast;
    
    // Status channel (not used but must be connected)
    wire        status_tvalid;
    reg         status_tready;
    wire [7:0]  status_tdata;
    
    // Event signals (for debugging)
    wire event_frame_started;
    wire event_tlast_unexpected;
    wire event_tlast_missing;
    wire event_status_channel_halt;
    wire event_data_in_channel_halt;
    wire event_data_out_channel_halt;
    
    //=========================================================================
    // Xilinx FFT IP Instantiation
    //=========================================================================
    xfft_0 fft_ip (
        .aclk(clk),
        
        // Config channel
        .s_axis_config_tdata(config_tdata),
        .s_axis_config_tvalid(config_tvalid),
        .s_axis_config_tready(config_tready),
        
        // Input data channel
        .s_axis_data_tdata(data_in_tdata),
        .s_axis_data_tvalid(data_in_tvalid),
        .s_axis_data_tready(data_in_tready),
        .s_axis_data_tlast(data_in_tlast),
        
        // Output data channel
        .m_axis_data_tdata(data_out_tdata),
        .m_axis_data_tuser(data_out_tuser),
        .m_axis_data_tvalid(data_out_tvalid),
        .m_axis_data_tready(data_out_tready),
        .m_axis_data_tlast(data_out_tlast),
        
        // Status channel
        .m_axis_status_tdata(status_tdata),
        .m_axis_status_tvalid(status_tvalid),
        .m_axis_status_tready(status_tready),
        
        // Event outputs
        .event_frame_started(event_frame_started),
        .event_tlast_unexpected(event_tlast_unexpected),
        .event_tlast_missing(event_tlast_missing),
        .event_status_channel_halt(event_status_channel_halt),
        .event_data_in_channel_halt(event_data_in_channel_halt),
        .event_data_out_channel_halt(event_data_out_channel_halt)
    );
    
    //=========================================================================
    // Control State Machine - Synchronous reset for RAM compatibility
    //=========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            sample_counter <= 10'd0;
            config_tvalid <= 1'b1;
            config_done <= 1'b0;
            data_in_tvalid <= 1'b0;
            data_in_tdata <= 32'd0;
            data_in_tlast <= 1'b0;
            data_out_tready <= 1'b0;
            status_tready <= 1'b1;  // Always ready for status
            frame_consumed <= 1'b0;
            fft_bin_data <= 32'd0;
            fft_bin_valid <= 1'b0;
            fft_bin_last <= 1'b0;
            
        end else begin
            // Default values
            frame_consumed <= 1'b0;
            fft_bin_valid <= 1'b0;
            fft_bin_last <= 1'b0;
            status_tready <= 1'b1;  // Always consume status

            // Send FFT configuration once after reset.
            if (!config_done) begin
                if (config_tready) begin
                    config_tvalid <= 1'b0;
                    config_done <= 1'b1;
                end else begin
                    config_tvalid <= 1'b1;
                end
            end
            
            case (state)
                //-------------------------------------------------------------
                STATE_IDLE: begin
                    data_in_tvalid <= 1'b0;
                    data_in_tlast <= 1'b0;

                    // Wait for FFT IP ready (tready) before starting frame input
                    if (config_done && frame_sample_valid && data_in_tready) begin
                        data_in_tdata <= {frame_sample, 16'd0};
                        data_in_tvalid <= 1'b1;
                        sample_counter <= 10'd1;
                        state <= STATE_STREAM_IN;
                    end
                end
                
                //-------------------------------------------------------------
                STATE_STREAM_IN: begin
                    // Stream 512 samples into FFT (serial input)
                    // AXI-Stream: advance only when tready accepts the sample.
                    // Xilinx FFT pipelined streaming mode holds tready=1
                    // during frame input, so this is a defensive check.
                    if (frame_sample_valid) begin
                        // Pack real sample with zero imaginary
                        // TDATA format: [31:16]=real, [15:0]=imag
                        data_in_tdata <= {frame_sample, 16'd0};
                        data_in_tvalid <= 1'b1;
                        
                        if (data_in_tready) begin
                            if (sample_counter == 10'd511) begin
                                // Last sample accepted
                                data_in_tlast <= 1'b1;
                                frame_consumed <= 1'b1;
                                sample_counter <= 10'd0;
                                state <= STATE_WAIT_OUTPUT;
                            end else begin
                                data_in_tlast <= 1'b0;
                                sample_counter <= sample_counter + 10'd1;
                            end
                        end
                    end else begin
                        data_in_tvalid <= 1'b0;
                        data_in_tlast <= 1'b0;
                    end
                end
                
                //-------------------------------------------------------------
                STATE_WAIT_OUTPUT: begin
                    // Wait for first output
                    data_in_tvalid <= 1'b0;
                    data_in_tlast <= 1'b0;
                    if (data_out_tvalid) begin
                        state <= STATE_STREAM_OUT;
                        data_out_tready <= 1'b1;
                        sample_counter <= 10'd0;
                    end
                end
                
                //-------------------------------------------------------------
                STATE_STREAM_OUT: begin
                    // Stream 257 output bins serially to downstream
                    // No storage arrays - direct passthrough
                    if (data_out_tvalid && data_out_tready) begin
                        // Pass bin directly to output
                        // TDATA format: [31:16]=real, [15:0]=imag
                        fft_bin_data <= data_out_tdata;
                        fft_bin_valid <= 1'b1;
                        
                        if (data_out_tlast || sample_counter == 10'd256) begin
                            // Last bin
                            fft_bin_last <= 1'b1;
                            data_out_tready <= 1'b0;
                            state <= STATE_DONE;
                        end else begin
                            fft_bin_last <= 1'b0;
                            sample_counter <= sample_counter + 10'd1;
                        end
                    end
                end
                
                //-------------------------------------------------------------
                STATE_DONE: begin
                    // Pipeline complete, return to idle
                    // No fft_done pulse needed - downstream tracks fft_bin_last
                    state <= STATE_IDLE;
                end
                
                //-------------------------------------------------------------
                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
