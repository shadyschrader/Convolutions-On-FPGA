`timescale 1ns/1ps

module load_tb;

    // Parameters
    parameter IMAGE_WIDTH = 5;
    parameter IMAGE_HEIGHT = 5;
    parameter N = 3;
    parameter CLK_PERIOD = 10; // Clock period in ns

    // Testbench signals
    reg clk;
    reg rst;
    reg load_en;
    reg new_buffer;
    reg [(IMAGE_WIDTH*IMAGE_HEIGHT*8)-1:0] image_mem_flat;
    wire [(N*IMAGE_WIDTH*8)-1:0] row_buffer_flat;
    wire loaded;

    // Instantiate the DUT (Device Under Test)
    load #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .N(N)
    ) dut (
        .clk(clk),
        .rst(rst),
        .load_en(load_en),
        .new_buffer(new_buffer),
        .image_mem_flat(image_mem_flat),
        .row_buffer_flat(row_buffer_flat),
        .loaded(loaded)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Monitor process to display matrix contents
    reg [31:0] i, j; // Use reg instead of integer for Verilog compatibility
    always @(posedge clk) begin
        if (load_en || new_buffer) begin
            #1; // Small delay to ensure values have propagated
            $display("\nTime: %0t", $time);
            $display("row_count: %0d, loaded: %0d, new_buffer: %0d", dut.row_count, loaded, new_buffer);
            $display("Row Buffer Internal Contents:");
            for (i = 0; i < N; i = i + 1) begin
                $write("Row %0d: ", i);
                for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                    $write("%3d ", dut.row_buffer_internal[i][j]);
                end
                $write("\n");
            end
        end
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst = 0;
        load_en = 0;
        new_buffer = 0;
        
        // Generate test image (5x5 matrix with incremental values)
        for (i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                image_mem_flat[(i*IMAGE_WIDTH + j)*8 +: 8] = i*IMAGE_WIDTH + j + 1;
            end
        end

        // Reset sequence
        #20 rst = 1;
        #20;

        // Display initial image memory
        $display("Initial Image Memory:");
        for (i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                $write("%3d ", dut.image_mem[i][j]);
            end
            $write("\n");
        end

        // Test case 1: Initial load
        @(posedge clk);
        load_en = 1;
        #20;
        load_en = 0;

        // Test case 2: Load next buffer
        repeat(2) begin
            @(posedge clk);
            new_buffer = 1;
            #20;
            new_buffer = 0;
            #40; // Wait to observe results
        end

        // Test case 3: Load when reaching end
        repeat(3) begin
            @(posedge clk);
            new_buffer = 1;
            #20;
            new_buffer = 0;
            #40;
        end

        #100;
        $finish;
    end

    // Dump variables for waveform viewing
    initial begin
        $dumpfile("load_tb.vcd");
        $dumpvars(0, load_tb);
    end

endmodule