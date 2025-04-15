module load #(
    parameter IMAGE_WIDTH = 128,
    parameter IMAGE_HEIGHT = 128,
    parameter FILTER_SIZE = 3
) (
    input clk,
    input rst,
    input wire load_en,
    input wire new_buffer,
    input wire [(IMAGE_WIDTH*IMAGE_HEIGHT*8)-1 : 0] image_mem_flat,
    output reg [(FILTER_SIZE*IMAGE_WIDTH*8)-1:0] row_buffer_flat, // Packed array
    output reg loaded
);
    
    // Image memory - keep as is
    reg [7:0] image_mem [0:IMAGE_HEIGHT-1][0:IMAGE_WIDTH-1];
    
    // Internal row buffer for easier manipulation
    reg [7:0] row_buffer_internal [0:FILTER_SIZE-1][0:IMAGE_WIDTH-1];
    
    // Row counter
    reg [$clog2(IMAGE_HEIGHT):0] row_count;
    integer i, j;

    genvar ga, gb;
    generate
        for (ga = 0; ga < IMAGE_WIDTH; ga = ga + 1) begin
            for (gb = 0; gb < IMAGE_HEIGHT; gb = gb + 1) begin
                always @(*) begin
                    image_mem[ga][gb] = image_mem_flat[(ga*IMAGE_WIDTH + gb)*8 +: 8];
                end
            end
        end
    endgenerate

    // Convert internal buffer to flat output
    // ALWAYS COMBINATIONAL BLOCK APPROACH
    always @(*) begin
        for (i = 0; i < FILTER_SIZE; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                row_buffer_flat[(i*IMAGE_WIDTH+j)*8 +: 8] = row_buffer_internal[i][j];
            end
        end
    end

always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < FILTER_SIZE; i = i + 1) begin
                for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                    row_buffer_internal[i][j] <= 0;
                end
            end
            row_count <= 0;
            loaded <= 0;
        end else begin
            if (load_en || new_buffer) begin
                loaded <= (row_count + FILTER_SIZE <= IMAGE_HEIGHT);
                if (row_count + FILTER_SIZE <= IMAGE_HEIGHT) begin
                    for (i = 0; i < FILTER_SIZE; i = i + 1) begin
                        for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                            row_buffer_internal[i][j] <= image_mem[i + row_count][j];
                        end
                    end
                end
                if (new_buffer) begin
                    if (row_count + FILTER_SIZE + 1 <= IMAGE_HEIGHT) begin
                        row_count <= row_count + 1;
                    end else begin
                        row_count <= 0;
                    end
                end
            end else begin
                loaded <= 0;
            end
        end
    end

endmodule