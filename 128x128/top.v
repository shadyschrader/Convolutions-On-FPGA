module top #(
    parameter IMAGE_WIDTH = 128,
    parameter IMAGE_HEIGHT = 128,
    parameter FILTER_SIZE = 3,
    parameter OUT = IMAGE_HEIGHT - FILTER_SIZE + 1
) (
    input clk,
    input rst,
    input wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] filter,
    output wire [31:0] result,
    output reg load_done,
    output reg shift_done,
    output reg convolve_done,
    output reg done
);

    // Define address widths for BRAMs
    localparam INPUT_ADDR_WIDTH = $clog2(IMAGE_HEIGHT * IMAGE_WIDTH); // 14 bits
    localparam OUTPUT_ADDR_WIDTH = $clog2(OUT * OUT); // 14 bits
    
    // Input BRAM signals - FIXED: Changed reg to wire for BRAM-driven signals
    reg [INPUT_ADDR_WIDTH-1:0] input_bram_addr_a;
    reg [7:0] input_bram_din_a;
    wire [7:0] input_bram_dout_a;
    reg input_bram_en_a;
    reg [0:0] input_bram_we_a;  // Changed to proper width
    
    // FIXED: These signals are now wires since they're driven by the load module
    wire [INPUT_ADDR_WIDTH-1:0] input_bram_addr_b;
    wire [7:0] input_bram_dout_b;
    wire input_bram_en_b;
    
    // Output BRAM signals
    reg [OUTPUT_ADDR_WIDTH-1:0] output_bram_addr_a;
    reg [31:0] output_bram_din_a;
    wire [31:0] output_bram_dout_a;
    reg output_bram_en_a;
    reg [0:0] output_bram_we_a;  // Changed to proper width
    
    // Streaming output signals
    reg [OUTPUT_ADDR_WIDTH-1:0] stream_addr;
    reg streaming_active;
    reg result_valid;
    
    // Instantiate Input BRAM
    input_image_bram input_bram (
        .clka(clk),
        .ena(input_bram_en_a),
        .wea(input_bram_we_a),
        .addra(input_bram_addr_a),
        .dina(input_bram_din_a),
        .douta(input_bram_dout_a),
        
        .clkb(clk),
        .enb(input_bram_en_b),      // Now a wire - driven by load module
        .addrb(input_bram_addr_b),  // Now a wire - driven by load module
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
    
    // Streaming output assignment
//    assign result = (streaming_active && result_valid) ? output_bram_dout_a : 16'h0000;
    assign result = output_bram_dout_a;
    
    
    wire [(FILTER_SIZE*IMAGE_WIDTH*8)-1:0] row_buffer_flat;
    wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] window;
    wire load_en, shift_en, mult_en;
    wire loaded, window_valid, new_buffer, conv_result_valid, shift_buffer;
    wire [31:0] result_image;

    reg [1:0] state;
    parameter IDLE      = 2'b00,
              PROCESS   = 2'b01,
              STREAM_OUT = 2'b10,
              COMPLETE  = 2'b11;
              
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
    wire all_windows_done = (row_count == OUT-1 && col_count == OUT-1 && conv_result_valid);
    
    // Output storage counter
    reg [OUTPUT_ADDR_WIDTH:0] output_store_counter;
    reg output_stored;
    
    // Writing Data to the Output BRAM
    reg[1:0] write_latency;

    // Streaming control
    reg [1:0] stream_delay; // Delay counter for BRAM read latency

// Fixed FSM Logic in top module - replace the always block
    always @(posedge clk) begin
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
            
            output_bram_en_a <= 0;
            output_bram_we_a <= 0;
            output_bram_addr_a <= 0;
            output_bram_din_a <= 0;
            
            output_store_counter <= 0;
            output_stored <= 0;
            
            // Streaming signals
            stream_addr <= 0;
            streaming_active <= 0;
            result_valid <= 0;
            write_latency <= 0;
            stream_delay <= 0;
        end else begin
            case (state)
                IDLE: begin
                    $display("FSM: Starting processing at time %t", $time);
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    case (process_state)
                        LOAD: begin
                            if (loaded) begin
                                load_done <= 1;
                                process_state <= SHIFT;
                                $display("FSM: Load complete, moving to SHIFT at time %t", $time);
                            end else begin
                                $display("FSM: Waiting for load completion at time %t", $time);
                            end
                        end
                        
                        SHIFT: begin
                            if (window_valid) begin
                                shift_done <= 1;
                                process_state <= CONVOLVE;
                                $display("FSM: Shift complete, moving to CONVOLVE at time %t", $time);
                            end else begin
                                // Reset shift_done if we're still waiting
                                shift_done <= 0;
                                $display("FSM: Waiting for window_valid at time %t, window_valid=%b", $time, window_valid);
                            end
                        end
                        
                        CONVOLVE: begin
                            if (conv_result_valid) begin
                                convolve_done <= 1;
                                process_state <= STORE;
                                $display("FSM: Convolve complete, moving to STORE at time %t", $time);
                            end else begin
                                $display("FSM: Waiting for  conv_result_valid at time %t, conv_result_valid=%b", $time, conv_result_valid);
                            end
                        end
                        
                        STORE: begin
                            // Only execute store logic if we haven't stored yet
                            if (!output_stored) begin
                                // Store result to output BRAM
                                    output_bram_en_a <= 1;
                                    output_bram_we_a <= 1;
                                    output_bram_addr_a <= row_count*OUT + col_count;
                                    output_bram_din_a <= result_image;
                                    output_stored <= 1;  // Mark as stored
                                    
                                    $display("FSM: Storing result at addr %d, row=%d, col=%d, result=%d", 
                                            row_count*OUT + col_count, row_count, col_count, output_bram_din_a);
                            end else begin
                                // Store is complete, disable write
                                output_bram_we_a <= 0;
                                
                                // Clear one-shot signals
                                load_done <= 0;
                                shift_done <= 0;
                                convolve_done <= 0;
                                output_stored <= 0;  // Reset for next iteration
                                
                                // Decide next state
                                if (new_buffer && (row_count < OUT-1)) begin
                                    $display("FSM: Moving to next row %d", row_count + 1);
                                    row_count <= row_count + 1;
                                    col_count <= 0;
                                    process_state <= LOAD;
                                end else if (col_count < OUT-1) begin
                                    $display("FSM: Moving to next column %d", col_count + 1);
                                    col_count <= col_count + 1;
                                    process_state <= SHIFT;
                                end else begin
                                    $display("FSM: All processing complete, moving to STREAM_OUT");
                                    state <= STREAM_OUT;
                                    stream_addr <= 0;
                                    streaming_active <= 1;
                                    output_bram_en_a <= 1;
                                    output_bram_we_a <= 0;  
                                    stream_delay <= 0;
                                end
                            end
                        end
                    endcase
                end
                
                STREAM_OUT: begin
                    if (streaming_active) begin
                        
                        if (stream_delay < 2) begin
                            // Set address only once at the beginning
                            if (stream_delay == 0) begin
                                output_bram_addr_a <= stream_addr;
                            end else if (stream_delay == 1)begin
                                result_valid <= 1;
                            end
                            stream_delay <= stream_delay + 1;
                            //result_valid <= 0;
                        end else begin
                            // Now data should be valid
                            result_valid <= 0;
                            $display("READING: addr=%d, data=%d, out=%d delay=%d, bram_enable=%d, streaming_active=%b, result_valid=%b", 
                                        output_bram_addr_a, output_bram_dout_a, result, stream_delay, output_bram_en_a, streaming_active, result_valid);
                                        
                            if (stream_addr < (OUT * OUT - 1)) begin
                                stream_addr <= stream_addr + 1;
                                stream_delay <= 0;  // Reset for next address
                            end else begin
                                streaming_active <= 0;
                                //result_valid <= 0;
                                output_bram_en_a <= 0;
                                state <= COMPLETE;
                            end
                        end
                    end
                end
                
                COMPLETE: begin
                    done <= 1;
                    $display("FSM: Processing COMPLETE at time %t", $time);
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
        .bram_en_b(input_bram_en_b),      // FIXED: Now output from load module
        .bram_addr_b(input_bram_addr_b),  // FIXED: Now output from load module
        .bram_data_b(input_bram_dout_b),  // Input to load module
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
        .result_valid(conv_result_valid),  // Renamed to avoid confusion
        .shift_buffer(shift_buffer)
    );

endmodule