`timescale 1ns/1ps

module convolve_tb;
    // Parameters
    parameter N = 3;
    parameter FILTER_SIZE = 3;
    parameter CLK_PERIOD = 10;

    // Testbench signals
    reg clk;
    reg rst;
    reg mult_en;
    reg [(N*FILTER_SIZE*8)-1:0] window_in;
    reg [(FILTER_SIZE*FILTER_SIZE*8)-1:0] filter_flat;
    wire [15:0] result;
    wire result_valid;
    wire shift_buffer;

    // Instantiate the DUT
    convolve #(
        .N(N),
        .FILTER_SIZE(FILTER_SIZE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .mult_en(mult_en),
        .window_in(window_in),
        .filter_flat(filter_flat),
        .result(result),
        .result_valid(result_valid),
        .shift_buffer(shift_buffer)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Monitor process
    always @(posedge clk) begin
        if (mult_en || result_valid || shift_buffer || !rst) begin
            #1; // Small delay to let values settle
            $display("\nTime: %0t", $time);
            $display("mult_en: %b, computing: %b, result_valid: %b, shift_buffer: %b", 
                     mult_en, dut.computing, result_valid, shift_buffer);
            $display("Result: %d", result);
        end
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst = 0;
        mult_en = 0;
        window_in = 0;
        filter_flat = 0;

        // Sample 3x3 window and filter
        window_in = {8'd7, 8'd8, 8'd9,    // Row 2
                     8'd4, 8'd5, 8'd6,    // Row 1
                     8'd1, 8'd2, 8'd3};   // Row 0
        filter_flat = {8'd2, 8'd0, 8'd2,  // Simple averaging filter (all 1s)
                       8'd2, 8'd0, 8'd2,
                       8'd2, 8'd0, 8'd2};

        // Reset sequence
        #20 rst = 1;
        #20 rst = 0;
        #20;

        // Display initial inputs
        $display("Initial Window In:");
        $display("  %d %d %d", window_in[23:16], window_in[15:8], window_in[7:0]);
        $display("  %d %d %d", window_in[47:40], window_in[39:32], window_in[31:24]);
        $display("  %d %d %d", window_in[71:64], window_in[63:56], window_in[55:48]);
        $display("Filter:");
        $display("  %d %d %d", filter_flat[23:16], filter_flat[15:8], filter_flat[7:0]);
        $display("  %d %d %d", filter_flat[47:40], filter_flat[39:32], filter_flat[31:24]);
        $display("  %d %d %d", filter_flat[71:64], filter_flat[63:56], filter_flat[55:48]);

        // Test case 1: Perform convolution
        @(posedge clk);
        mult_en = 1;
        #10 mult_en = 0;
        #20;

        // // Test case 2: Perform another convolution with same inputs
        // @(posedge clk);
        // mult_en = 1;
        // #10 mult_en = 0;
        // #20;

        rst = 1;

        #100;
        $finish;
    end

    // Dump waveform
    initial begin
        $dumpfile("convolve.vcd");
        $dumpvars(0, convolve_tb);
    end

endmodule