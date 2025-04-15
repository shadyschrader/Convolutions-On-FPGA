module shift #(
    parameter IMAGE_WIDTH = 9,
    parameter IMAGE_HEIGHT = 9,  // Added for N calculation
    // parameter N = IMAGE_HEIGHT - FILTER_SIZE + 1,  // N = 7 for 9x9 image, 3x3 filter
    parameter FILTER_SIZE = 3
) (
    input wire clk,
    input wire rst,
    input wire shift_en,
    input wire shift_buffer,
    input wire [(FILTER_SIZE*IMAGE_WIDTH*8)-1:0] row_buffer_in,  // Changed N to FILTER_SIZE
    output reg [(FILTER_SIZE*FILTER_SIZE*8)-1:0] window_out,
    output reg window_valid,
    output reg new_buffer
);

    reg [(IMAGE_WIDTH):0] col_pos;
    wire at_end;

    integer i, j;

    // Extract 3x3 window from the buffer based on current position
    always @(*) begin
        for (i = 0; i < FILTER_SIZE; i = i + 1) begin  // Changed N to FILTER_SIZE
            for (j = 0; j < FILTER_SIZE; j = j + 1) begin
                window_out[(i*FILTER_SIZE+j)*8 +: 8] = row_buffer_in[(i*IMAGE_WIDTH + (col_pos+j))*8 +: 8];
            end
        end
    end

    // Check if we're at the end of the buffer
    assign at_end = (col_pos + FILTER_SIZE) >= IMAGE_WIDTH;

    // Control logic
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            col_pos <= 0;
            window_valid <= 0;
            new_buffer <= 0;
        end
        else if (shift_buffer && !shift_en) begin
            $display("sift_buffer active");
            if (!at_end) begin
                col_pos <= col_pos + 1;
                window_valid <= 1;
                new_buffer <= 0;
                if (window_valid) begin
                    $display("Shift Window at Time %0t, col_pos: %d", $time, col_pos);
                    for (i = 0; i < FILTER_SIZE; i = i + 1) begin  // Changed N to FILTER_SIZE
                        $write("  ");
                        for (j = 0; j < FILTER_SIZE; j = j + 1) begin
                            $write("%3d ", window_out[(i*FILTER_SIZE + j)*8 +: 8]);
                        end
                        $write("\n");
                    end
                end
            end
            else begin
                col_pos <= 0;
                window_valid <= 0;
                new_buffer <= 1;
            end
        end
        else if (shift_en && col_pos == 0) begin
            $display("shift_en active");
            col_pos <= 0;
            window_valid <= 1;
            new_buffer <= 0;
        end
        else begin
            new_buffer <= 0;
        end
    end

endmodule