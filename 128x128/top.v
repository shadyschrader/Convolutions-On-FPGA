module top #(
    parameter IMAGE_WIDTH = 128,
    parameter IMAGE_HEIGHT = 128,
    parameter FILTER_SIZE = 3,
    parameter OUT = IMAGE_HEIGHT - FILTER_SIZE + 1
) (
    input clk,
    input rst,
    input wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] filter,
    output wire [(OUT*OUT*16)-1:0] result,
    output reg load_done,
    output reg shift_done,
    output reg convolve_done,
    output reg done
);

    // Define address widths for BRAMs
    localparam INPUT_ADDR_WIDTH = $clog2(IMAGE_HEIGHT * IMAGE_WIDTH); // 14 bits
    localparam OUTPUT_ADDR_WIDTH = $clog2(OUT * OUT); // 14 bits
    
    // Input BRAM signals
    reg [INPUT_ADDR_WIDTH-1:0] input_bram_addr_a;
    reg [7:0] input_bram_din_a;
    wire [7:0] input_bram_dout_a;
    reg input_bram_en_a;
    reg input_bram_we_a;
    
    reg [INPUT_ADDR_WIDTH-1:0] input_bram_addr_b;
    wire [7:0] input_bram_dout_b;
    reg input_bram_en_b;
    
    // Output BRAM signals
    reg [OUTPUT_ADDR_WIDTH-1:0] output_bram_addr_a;
    reg [15:0] output_bram_din_a;
    wire [15:0] output_bram_dout_a;
    reg output_bram_en_a;
    reg output_bram_we_a;
    
    // Instantiate Input BRAM
    input_image_bram input_bram (
        .clka(clk),
        .ena(input_bram_en_a),
        .wea(input_bram_we_a),
        .addra(input_bram_addr_a),
        .dina(input_bram_din_a),
        .douta(input_bram_dout_a),
        
        .clkb(clk),
        .enb(input_bram_en_b),
        .addrb(input_bram_addr_b),
        .doutb(input_bram_dout_b)
    );
    
    // Instantiate Output BRAM
    output_bram output_image_bram (
        .clka(clk),
        .ena(output_bram_en_a),
        .wea(output_bram_we_a),
        .addra(output_bram_addr_a),
        .dina(output_bram_din_a),
        .douta(output_bram_dout_a)
    );
    
    // Placeholder for result output
    assign result = 0; // TODO: Implement BRAM read mechanism if needed
    
    wire [(FILTER_SIZE*IMAGE_WIDTH*8)-1:0] row_buffer_flat;
    wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] window;
    wire load_en, shift_en, mult_en;
    wire loaded, window_valid, new_buffer, result_valid, shift_buffer;
    wire [15:0] result_image;

    reg [1:0] state;
    parameter IDLE      = 2'b00,
              PROCESS   = 2'b01,
              STORE_OUT = 2'b10;
              
    reg [1:0] process_state;
    parameter LOAD     = 2'b00,
              SHIFT    = 2'b01,
              CONVOLVE = 2'b10,
              STORE    = 2'b11;

    // FSM Logic
    assign load_en = (process_state == LOAD && state == PROCESS);
    assign shift_en = (process_state == SHIFT && state == PROCESS);
    assign mult_en = (process_state == CONVOLVE && state == PROCESS);

    reg [15:0] row_count, col_count;
    wire all_windows_done = (row_count == OUT-1 && col_count == OUT-1 && result_valid);
    
    // Output storage counter
    reg [OUTPUT_ADDR_WIDTH:0] output_store_counter;
    reg output_stored;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            process_state <= LOAD;
            load_done <= 0;
            shift_done <= 0;
            convolve_done <= 0;
            done <= 0;
            row_count <= 0;
            col_count <= 0;
            
            // Initialize BRAM control signals
            input_bram_en_a <= 0;
            input_bram_we_a <= 0;
            input_bram_addr_a <= 0;
            input_bram_din_a <= 0;
            input_bram_en_b <= 0;
            input_bram_addr_b <= 0;
            
            output_bram_en_a <= 0;
            output_bram_we_a <= 0;
            output_bram_addr_a <= 0;
            output_bram_din_a <= 0;
            
            output_store_counter <= 0;
            output_stored <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Start processing directly (BRAM is preloaded)
                    state <= PROCESS;
                    input_bram_en_b <= 1; // Enable BRAM port B for reading
                end
                
                PROCESS: begin
                    // Process the image using load-shift-convolve pipeline
                    case (process_state)
                        LOAD: begin
                            if (loaded) begin
                                load_done <= 1;
                                process_state <= SHIFT;
                            end
                        end
                        
                        SHIFT: begin
                            if (window_valid) begin
                                shift_done <= 1;
                                process_state <= CONVOLVE;
                            end
                        end
                        
                        CONVOLVE: begin
                            if (result_valid) begin
                                convolve_done <= 1;
                                process_state <= STORE;
                            end
                        end
                        
                        STORE: begin
                            // Store result to output BRAM
                            output_bram_en_a <= 1;
                            output_bram_we_a <= 1;
                            output_bram_addr_a <= row_count*OUT + col_count;
                            output_bram_din_a <= result_image;
                            
                            if (new_buffer && row_count < OUT-1) begin
                                row_count <= row_count + 1;
                                col_count <= 0;
                                process_state <= LOAD;
                                load_done <= 0;
                                shift_done <= 0;
                                convolve_done <= 0;
                            end else if (col_count < OUT-1) begin
                                col_count <= col_count + 1;
                                shift_done <= 0;
                                convolve_done <= 0;
                                process_state <= SHIFT;
                            end else if (all_windows_done) begin
                                state <= STORE_OUT;
                                output_store_counter <= 0;
                                output_bram_we_a <= 0; // Stop writing
                            end
                        end
                    endcase
                end
                
                STORE_OUT: begin
                    // Complete - signal done
                    done <= 1;
                    // TODO: Implement BRAM read for result if needed
                end
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
        .bram_en_b(input_bram_en_b),
        .bram_addr_b(input_bram_addr_b),
        .bram_data_b(input_bram_dout_b),
        .row_buffer_flat(row_buffer_flat),
        .loaded(loaded),
        .row_count(row_count)
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