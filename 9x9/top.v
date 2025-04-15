module top #(
    parameter IMAGE_WIDTH = 9,
    parameter IMAGE_HEIGHT = 9,
    parameter FILTER_SIZE = 3,
    parameter OUT = IMAGE_HEIGHT - FILTER_SIZE + 1
) (
    input clk,
    input rst,
    input wire [(IMAGE_HEIGHT*IMAGE_WIDTH)*8-1:0] image,
    input wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] filter,
    output reg [(OUT*OUT*16)-1:0] result,
    output reg load_done,
    output reg shift_done,
    output reg convolve_done,
    output reg done
);

    wire [(FILTER_SIZE*IMAGE_WIDTH*8)-1:0] row_buffer_flat;
    wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] window;  // Adjusted to 3x3
    wire load_en, shift_en, mult_en;
    wire loaded, window_valid, new_buffer, result_valid, shift_buffer;
    wire [15:0] result_image;

    reg [1:0] state;
    parameter LOAD     = 2'b00,
              SHIFT    = 2'b01,
              CONVOLVE = 2'b10,
              STORE    = 2'b11;

    assign load_en = (state == LOAD);
    assign shift_en = (state == SHIFT);
    assign mult_en = (state == CONVOLVE);

    reg [15:0] row_count, col_count;  // 3 bits for 0-7   Track 3x3 output positions
    wire all_windows_done = (row_count == OUT-1 && col_count == OUT-1 && result_valid);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= LOAD;
            load_done <= 0;
            shift_done <= 0;
            convolve_done <= 0;
            done <= 0;
            row_count <= 0;
            col_count <= 0;
            result <= 0;
        end else begin
            case (state)
                LOAD: begin
                    if (loaded) begin
                        load_done <= 1;
                        state <= SHIFT;
                    end
                end
                
                SHIFT: begin
                    if (window_valid) begin
                        shift_done <= 1;
                        state <= CONVOLVE;
                    end
                end
                
                CONVOLVE: begin
                    if (result_valid) begin
                        convolve_done <= 1;
                        state <= STORE;
                    end
                end
                
                STORE: begin
                    result[(row_count*OUT + col_count)*16 +: 16] <= result_image;  // Store 16-bit result
                    if (new_buffer && row_count < OUT-1) begin
                        row_count <= row_count + 1;
                        col_count <= 0;
                        state <= LOAD;  // Load next buffer
                        load_done <= 0;
                        shift_done <= 0;
                        convolve_done <= 0;
                    end else if (col_count < OUT-1) begin
                        col_count <= col_count + 1;
                        shift_done <= 0;
                        convolve_done <= 0;
                        state <= SHIFT;  // Next window in same buffer
                    end else if (all_windows_done) begin
                        done <= 1;
                        state <= LOAD;  // Done with all windows
                    end
                end
                
                default: state <= LOAD;
            endcase
        end
    end

    // MODULE INSTANTIATIONS
    load #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .FILTER_SIZE(FILTER_SIZE)
    ) inst_load (
        .clk(clk),
        .rst(rst),
        .load_en(load_en),
        .new_buffer(new_buffer),
        .image_mem_flat(image),
        .row_buffer_flat(row_buffer_flat),
        .loaded(loaded)
    );

    shift #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .FILTER_SIZE(FILTER_SIZE)
    ) inst_shift (
        .clk(clk),
        .rst(rst),
        .shift_en(shift_en),
        .shift_buffer(shift_buffer),
        .row_buffer_in(row_buffer_flat),
        .window_out(window),
        .window_valid(window_valid),
        .new_buffer(new_buffer)
    );
    
    convolve #(
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .OUT(OUT),
        .FILTER_SIZE(FILTER_SIZE)
    ) inst_convolve (
        .clk(clk),
        .rst(rst),
        .mult_en(mult_en),
        .window_in(window),
        .filter_flat(filter),
        .result(result_image),
        .result_valid(result_valid),
        .shift_buffer(shift_buffer)
    );

endmodule