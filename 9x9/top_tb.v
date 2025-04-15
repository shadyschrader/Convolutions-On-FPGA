`timescale 1ns/1ps

module tb_top;
    // Parameters
    parameter IMAGE_WIDTH = 9;
    parameter IMAGE_HEIGHT = 9;
    parameter FILTER_SIZE = 3;
    parameter OUT = IMAGE_HEIGHT - FILTER_SIZE + 1;
    parameter CLK_PERIOD = 10;

    // Testbench signals
    reg clk;
    reg rst;
    reg [(IMAGE_HEIGHT*IMAGE_WIDTH*8)-1:0] image;
    reg [(FILTER_SIZE*FILTER_SIZE*8)-1:0] filter;
    wire [(OUT*OUT*16)-1:0] result;
    wire load_done, shift_done, convolve_done, done;

    // Instantiate the DUT
    top #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .FILTER_SIZE(FILTER_SIZE),
        .OUT(OUT)
    ) dut (
        .clk(clk),
        .rst(rst),
        .image(image),
        .filter(filter),
        .result(result),
        .load_done(load_done),
        .shift_done(shift_done),
        .convolve_done(convolve_done),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus and display
    integer i, j;
    initial begin
        // Initialize signals
        rst = 0;
        image = 0;
        filter = 0;

        // Generate 5x5 test image (1 to 25)
        for (i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                image[(i*IMAGE_WIDTH + j)*8 +: 8] = i*IMAGE_WIDTH + j + 1;
            end
        end

        // Simple 3x3 filter (all 1s for summation)
        for (i = 0; i < FILTER_SIZE; i = i + 1) begin
            for (j = 0; j < FILTER_SIZE; j = j + 1) begin
                filter[(i*FILTER_SIZE + j)*8 +: 8] = 1;
            end
        end

        // Display initial image
        $display("Initial Image (5x5):");
        for (i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            $write("  ");
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                $write("%3d ", image[(i*IMAGE_WIDTH + j)*8 +: 8]);
            end
            $write("\n");
        end

        // Display filter
        $display("Filter (3x3):");
        for (i = 0; i < FILTER_SIZE; i = i + 1) begin
            $write("  ");
            for (j = 0; j < FILTER_SIZE; j = j + 1) begin
                $write("%3d ", filter[(i*FILTER_SIZE + j)*8 +: 8]);
            end
            $write("\n");
        end

        // Reset sequence
        #20 rst = 1;
        #10;
        
        #5000;
        // Run until convolution is done
        wait(done);
        #20;  // Wait to capture final state

        // Display final result
        $display("\nConvolution Result (3x3):");
        for (i = 0; i < OUT; i = i + 1) begin
            $write("  ");
            for (j = 0; j < OUT; j = j + 1) begin
                $write("%5d ", result[(i*OUT + j)*16 +: 16]);
            end
            $write("\n");
        end

        #20 rst = 1;
        #100;
        $finish;
    end

    // Monitor pipeline states
    always @(posedge clk) begin
        if (rst || load_done || shift_done || convolve_done || done) begin
            #1;  // Small delay to let signals settle
            $display("\nTime: %0t", $time);
            $display("State: %b, row_count: %d, col_count: %d", 
                     dut.state, dut.row_count, dut.col_count);
            $display("rst: %b, load_done: %b, shift_done: %b, convolve_done: %b, done: %b", 
                     rst, load_done, shift_done, convolve_done, done);
            $display("loaded: %b, window_valid: %b, result_valid: %b, new_buffer: %b, shift_buffer: %b", 
                     dut.loaded, dut.window_valid, dut.result_valid, dut.new_buffer, dut.shift_buffer);
            if (convolve_done) begin
                $display("Current result_image: %d", dut.result_image);
            end
        end
    end

    // Dump waveform
    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, tb_top);
    end

endmodule