module shift #(
    parameter IMAGE_WIDTH = 128,
    parameter IMAGE_HEIGHT = 128,
    parameter FILTER_SIZE = 3
) (
    input wire clk,
    input wire rst,
    input wire shift_en,
    input wire shift_buffer,
    input wire [(FILTER_SIZE*IMAGE_WIDTH*8)-1:0] row_buffer_in,
    output reg [(FILTER_SIZE*FILTER_SIZE*8)-1:0] window_out,
    output reg window_valid,
    output reg new_buffer
);

    reg [(IMAGE_WIDTH):0] col_pos;
    reg shift_buffer_prev; // To detect rising edge of shift_buffer
    wire at_end;
    wire shift_buffer_rising;
    integer i, j;
    reg delay;
    
    // Detect rising edge of shift_buffer
    // assign shift_buffer_rising = shift_buffer && !shift_buffer_prev;
    
    // Extract 3x3 window from the buffer based on current position
    always @(*) begin
        for (i = 0; i < FILTER_SIZE; i = i + 1) begin
            for (j = 0; j < FILTER_SIZE; j = j + 1) begin
                window_out[(i*FILTER_SIZE+j)*8 +: 8] = row_buffer_in[(i*IMAGE_WIDTH + (col_pos+j))*8 +: 8];
            end
        end
    end
    
    // Check if we're at the end of the buffer
    assign at_end = (col_pos + FILTER_SIZE) >= IMAGE_WIDTH;
    
    // Control logic
    always @(posedge clk) begin
        if (!rst) begin
            col_pos <= 0;
            window_valid <= 0;
            new_buffer <= 0;
            //shift_buffer <= 0;
            shift_buffer_prev <= 0;
            delay <=0;
        end else begin
            //shift_buffer_prev <= shift_buffer; // Track previous state
            
            if (shift_en) begin
                // Initial shift enable - show first window
                $display("SHIFT: shift_en active at time %t", $time);
                window_valid <= 1;
                new_buffer <= 0;
                
                $display("SHIFT: Window at col_pos: %d", col_pos);
                for (i = 0; i < FILTER_SIZE; i = i + 1) begin
                    $write("  ");
                    for (j = 0; j < FILTER_SIZE; j = j + 1) begin
                        $write("%3d ", window_out[(i*FILTER_SIZE + j)*8 +: 8]);
                    end
                    $write("\n");
                end
                
            end else if (shift_buffer) begin
                // Shift buffer signal from convolve module
                //$display("SHIFT: shift_buffer rising edge at time %t, col_pos=%d", $time, col_pos);
                
                if (!at_end) begin
                    // Move to next column
                    col_pos <= col_pos + 1;
                    window_valid <= 1;
                    new_buffer <= 0;
                    
                    $display("SHIFT: Moving to next column %d", col_pos + 1);
                    
                end else begin
                    // End of current row - need new buffer
                    $display("SHIFT: End of row reached, requesting new buffer");
                    col_pos <= 0;
                    window_valid <= 0;
                    new_buffer <= 1;
                    
                end
                
            end else begin
                if (new_buffer) begin
                    if(delay<1)begin
                        delay <= delay + 1;
                    end else begin
                        new_buffer <= 0; 
                        delay <= 0;
                    end
                    
                end
                if (window_valid && !shift_en) begin
                    window_valid <= 0; // Clear window_valid when not actively shifting
                end
            end
        end
    end

endmodule