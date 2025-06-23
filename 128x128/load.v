module load #(
    parameter IMAGE_WIDTH = 128,
    parameter IMAGE_HEIGHT = 128,
    parameter FILTER_SIZE = 3
) (
    input clk,
    input rst,
    input wire load_en,
    input wire new_buffer,
    // BRAM interface
    output reg bram_en_b,
    output reg [($clog2(IMAGE_HEIGHT*IMAGE_WIDTH))-1:0] bram_addr_b,
    input wire [7:0] bram_data_b,
    input wire [15:0] row_count,
    output reg [(FILTER_SIZE*IMAGE_WIDTH*8)-1:0] row_buffer_flat,
    output reg loaded
);

    // Internal row buffer
    reg [7:0] row_buffer_internal [0:FILTER_SIZE-1][0:IMAGE_WIDTH-1];
    
    // Convert internal buffer to flat output
    integer i, j;
    always @(*) begin
        for (i = 0; i < FILTER_SIZE; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                row_buffer_flat[(i*IMAGE_WIDTH+j)*8 +: 8] = row_buffer_internal[i][j];
            end
        end
    end
    
    // State machine for loading from BRAM
    reg [1:0] load_state;
    reg [$clog2(IMAGE_WIDTH):0] current_col;
    reg [$clog2(FILTER_SIZE):0] current_row;
    reg [1:0] read_delay; // Counter for BRAM read latency
    
    parameter IDLE = 2'b00, 
              SETUP_READ = 2'b01, 
              READ_WAIT = 2'b10, 
              DONE = 2'b11;
    
    always @(posedge clk) begin
        if (!rst) begin
            // Reset row buffer
            for (i = 0; i < FILTER_SIZE; i = i + 1) begin
                for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                    row_buffer_internal[i][j] <= 0;
                end
            end
            loaded <= 0;
            load_state <= IDLE;
            current_row <= 0;
            current_col <= 0;
            bram_en_b <= 0;
            bram_addr_b <= 0;
            read_delay <= 0;
        end else begin
            case (load_state)
                IDLE: begin
                    if (load_en) begin
                        $display("LOAD: Starting load operation at time %t, row_count=%d", $time, row_count);
                        load_state <= SETUP_READ;
                        current_row <= 0;
                        current_col <= 0;
                        bram_en_b <= 1;
                        loaded <= 0;
                        read_delay <= 0;
                    end
                end
                
                SETUP_READ: begin
                    // Set up BRAM address for current position
                    if ((row_count + current_row) < IMAGE_HEIGHT) begin
                        bram_addr_b <= (row_count + current_row) * IMAGE_WIDTH + current_col;
                        $display("LOAD: Reading addr %d (row=%d, col=%d)", 
                                (row_count + current_row) * IMAGE_WIDTH + current_col, 
                                row_count + current_row, current_col);
                    end else begin
                        // Handle boundary case - pad with zeros or repeat last row
                        bram_addr_b <= (IMAGE_HEIGHT - 1) * IMAGE_WIDTH + current_col;
                        $display("LOAD: Boundary case - using last row addr %d", 
                                (IMAGE_HEIGHT - 1) * IMAGE_WIDTH + current_col);
                    end
                    
                    load_state <= READ_WAIT;
                    read_delay <= 0;
                end
                
                READ_WAIT: begin
                    // Wait for BRAM read latency
                    if (read_delay < 2) begin
                        read_delay <= read_delay + 1;
                    end else begin
                        // Capture data from BRAM
                        row_buffer_internal[current_row][current_col] <= bram_data_b;
                        $display("LOAD: Captured data %d at [%d][%d] at time = %t", bram_data_b, current_row, current_col,$time);
                        
                        // Move to next position
                        if (current_col < IMAGE_WIDTH - 1) begin
                            current_col <= current_col + 1;
                            load_state <= SETUP_READ;
                        end else if (current_row < FILTER_SIZE - 1) begin
                            current_col <= 0;
                            current_row <= current_row + 1;
                            load_state <= SETUP_READ;
                        end else begin
                            // All data loaded
                            $display("LOAD: All data loaded, moving to DONE");
                            load_state <= DONE;
                            bram_en_b <= 0;
                        end
                    end
                end
                
                DONE: begin
                    loaded <= 1;
                    $display("LOAD: Load complete at time %t", $time);
                    // Stay in DONE state until load_en goes low
                    if (!load_en) begin
                        load_state <= IDLE;
                        loaded <= 0;
                    end
                end
            endcase
        end
    end

endmodule