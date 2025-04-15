`timescale 1ns/1ps

module shift_tb;
    // Parameters
    parameter IMAGE_WIDTH = 5;
    parameter N = 3;
    parameter FILTER_SIZE = 3;
    parameter CLK_PERIOD = 10;

    // Testbench signals
    reg clk;
    reg rst;
    reg shift_en;
    reg shift_buffer;
    reg [(N*IMAGE_WIDTH*8)-1:0] row_buffer_in;
    wire [(N*FILTER_SIZE*8)-1:0] window_out;
    wire window_valid;
    wire new_buffer;

    // Instantiate the DUT
    shift #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .N(N),
        .FILTER_SIZE(FILTER_SIZE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .shift_en(shift_en),
        .shift_buffer(shift_buffer),
        .row_buffer_in(row_buffer_in),
        .window_out(window_out),
        .window_valid(window_valid),
        .new_buffer(new_buffer)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Monitor process
    integer i;
    always @(posedge clk) begin
        if (shift_en || shift_buffer || !rst) begin
            #1; // Small delay to let values settle
            $display("\nTime: %0t", $time);
            $display("col_pos: %0d, window_valid: %b, new_buffer: %b", dut.col_pos, window_valid, new_buffer);
            $display("Window Out (3x3):");
            for (i = 0; i < N; i = i + 1) begin
                $write("Row %0d: ", i);
                $write("%3d %3d %3d", 
                    window_out[(i*FILTER_SIZE+0)*8 +: 8],
                    window_out[(i*FILTER_SIZE+1)*8 +: 8],
                    window_out[(i*FILTER_SIZE+2)*8 +: 8]);
                $write("\n");
            end
        end
    end

    integer x, y;
    // Test stimulus
    initial begin
        // Initialize signals
        rst = 0;
        shift_en = 0;
        shift_buffer = 0;
        row_buffer_in = 0;

        // Sample row buffer (3 rows x 5 cols, values 1-15)
        // row_buffer_in = {8'd11, 8'd12, 8'd13, 8'd14, 8'd15,  // Row 2
        //                  8'd6,  8'd7,  8'd8,  8'd9,  8'd10,  // Row 1
        //                  8'd1,  8'd2,  8'd3,  8'd4,  8'd5};  // Row 0
        
        // After assigning row_buffer_in
        for (x = 0; x < N; x = x + 1) begin
            for (y = 0; y < IMAGE_WIDTH; y = y + 1) begin
                row_buffer_in[(x*IMAGE_WIDTH + y)*8 +: 8] = x*IMAGE_WIDTH + y + 1;
            end
        end

        // Display row_buffer_in
        $display("Row Buffer In Contents:");
        for (x = 0; x < N; x = x + 1) begin
            $write("Row %0d: ", x);
            for (y = 0; y < IMAGE_WIDTH; y = y + 1) begin
                $write("%3d ", row_buffer_in[(x*IMAGE_WIDTH + y)*8 +: 8]);
            end
            $write("\n");
        end

        // Reset sequence
        #20 rst = 1;
        #20;

        // Test case 1: Initial shift (shift_en)
        @(posedge clk);
        shift_en = 1;
        #10 shift_en = 0;
        #20;

        // Test case 2: Shift across buffer (shift_buffer)
        repeat(3) begin
            @(posedge clk);
            shift_buffer = 1;
            #10 shift_buffer = 0;
            #20; // Wait to observe
        end

        // Test case 3: New buffer request and restart
        @(posedge clk);
        shift_buffer = 1;  // Should trigger new_buffer
        #10 shift_buffer = 0;
        #20;
        @(posedge clk);
        shift_en = 1;      // Reload with shift_en
        #10 shift_en = 0;
        #20;

        #100;
        $finish;
    end

    // Dump waveform
    initial begin
        $dumpfile("shift.vcd");
        $dumpvars(0, shift_tb);
    end

endmodule