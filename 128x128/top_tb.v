`timescale 1ns / 1ps

module top_tb();
    // Parameters - adjust these to match your design
    parameter IMAGE_WIDTH = 128;
    parameter IMAGE_HEIGHT = 128;
    parameter FILTER_SIZE = 3;
    parameter OUT = IMAGE_HEIGHT - FILTER_SIZE + 1;
    parameter CLK_PERIOD = 10; // 100MHz clock
    
    // Testbench signals
    reg clk;
    reg rst;
    reg [(FILTER_SIZE*FILTER_SIZE*8)-1:0] filter;
    wire [31:0] result;
    wire load_done, shift_done, convolve_done, done;
    
    // Additional signals for monitoring
    integer cycle_count = 0;
    integer last_row_count = 0;
    integer last_col_count = 0;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Cycle counter
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
    end
    
    // DUT instantiation
    top #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .FILTER_SIZE(FILTER_SIZE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .filter(filter),
        .result(result),
        .load_done(load_done),
        .shift_done(shift_done),
        .convolve_done(convolve_done),
        .done(done)
    );
    
    // Main test sequence
    initial begin
        // Initialize
        rst = 0;
        filter = 0;
        
        $display("=== Starting Convolution Test ===");
        $display("Image size: %dx%d, Filter size: %dx%d, Output size: %dx%d", 
                 IMAGE_WIDTH, IMAGE_HEIGHT, FILTER_SIZE, FILTER_SIZE, OUT, OUT);
        
        // Reset pulse
        #(CLK_PERIOD*2);
        rst = 1;
        #(CLK_PERIOD*5);
        
        // Setup filter
        setup_test_filter();
        
        $display("=== Starting Processing at cycle %d ===", cycle_count);
        
        // Wait for completion with timeout
        fork
            begin: timeout_block
                #1000000; // 1ms timeout (100,000 cycles at 10ns period)
                $display("ERROR: Simulation timeout at cycle %d!", cycle_count);
                $display("Final state: state=%d, process_state=%d, row=%d, col=%d", 
                         dut.state, dut.process_state, dut.row_count, dut.col_count);
                $finish;
            end
            begin: wait_for_completion
                wait(done);
                $display("SUCCESS: Processing completed at cycle %d", cycle_count);
                disable timeout_block;
            end
        join
        
        // Verify output
        #(CLK_PERIOD*10);
        verify_output();
        
        $display("=== Test Complete ===");
        #(CLK_PERIOD*10);
        $finish;
    end

    // COE file generation task
    task generate_coe_file;
        integer coe_file;
        integer i;
        reg [31:0] read_data;
        begin
            $display("=== Generating COE file ===");
            
            // Open COE file for writing
            coe_file = $fopen("convolved_output.coe", "w");
            
            // Write COE header
            $fwrite(coe_file, "memory_initialization_radix=10;\n");
            $fwrite(coe_file, "memory_initialization_vector=\n");
            
            // Force the DUT to read from output BRAM
            force dut.output_bram_en_a = 1'b1;
            force dut.output_bram_we_a = 1'b0;
            
            // Read all data from output BRAM
            for (i = 0; i < (OUT * OUT); i = i + 1) begin
                // Set address
                force dut.output_bram_addr_a = i;
                
                // Wait for BRAM read latency (2 cycles)
                @(posedge clk);
                @(posedge clk);
                
                // Read the data
                read_data = dut.output_bram_dout_a;
                
                // Write to COE file
                if (i == (OUT * OUT - 1)) begin
                    $fwrite(coe_file, "%0d;", read_data);  // Last entry ends with semicolon
                end else begin
                    $fwrite(coe_file, "%0d,\n", read_data); // Other entries end with comma
                end
                
                $display("COE Export: addr=%0d, data=%0d", i, read_data);
            end
            
            // Release the forced signals
            release dut.output_bram_en_a;
            release dut.output_bram_we_a;
            release dut.output_bram_addr_a;
            
            $fclose(coe_file);
            $display("COE file 'convolved_output.coe' generated successfully!");
        end
    endtask
    
    // Setup test filter
    task setup_test_filter;
        begin
            // Simple 3x3 edge detection filter
            filter = {8'h 1, 8'h 0, 8'h 1,  // Top row
                     8'h 1, 8'h 0, 8'h 1,  // Middle row  
                     8'h 1, 8'h 0, 8'h 1}; // Bottom row
            
            $display("Filter setup complete: %h", filter);
        end
    endtask
    
    task verify_output;
        integer i;
        begin
            $display("=== Verifying Output ===");
            
            // Wait a few cycles after done signal
            #(CLK_PERIOD*5);
            
            // Generate COE file
            generate_coe_file();
            
            // Original verification code (showing first 10 values)
            $display("=== Sample Output Values ===");
            for (i = 0; i < 10; i = i + 1) begin
                // Manually read from BRAM for verification
                force dut.output_bram_en_a = 1'b1;
                force dut.output_bram_we_a = 1'b0;
                force dut.output_bram_addr_a = i;
                
                @(posedge clk);
                @(posedge clk);
                
                $display("Verification[%0d] = %0d", i, dut.output_bram_dout_a);
            end
            
            // Release forced signals
            release dut.output_bram_en_a;
            release dut.output_bram_we_a;
            release dut.output_bram_addr_a;
        end
    endtask

    
    
    // Enhanced monitoring - track progress and detect stalls
    always @(posedge clk) begin
        // Detect when row_count or col_count changes
        if (dut.row_count != last_row_count || dut.col_count != last_col_count) begin
            $display("PROGRESS: Cycle %d - Row %d, Col %d (State: %s, Process: %s)", 
                     cycle_count, dut.row_count, dut.col_count,
                     state_name(dut.state), process_name(dut.process_state));
            last_row_count = dut.row_count;
            last_col_count = dut.col_count;
        end
        
        // Monitor key transitions
        if (dut.state == 2'b01) begin // PROCESS state
            case (dut.process_state)
                2'b00: begin // LOAD
                    if (load_done && !shift_done) begin
                        $display("TRANSITION: LOAD -> SHIFT at cycle %d", cycle_count);
                    end
                end
                2'b01: begin // SHIFT
                    if (shift_done && !convolve_done) begin
                        $display("TRANSITION: SHIFT -> CONVOLVE at cycle %d", cycle_count);
                    end
                end
                2'b10: begin // CONVOLVE
                    if (convolve_done) begin
                        $display("TRANSITION: CONVOLVE -> STORE at cycle %d", cycle_count);
                    end
                end
                2'b11: begin // STORE
                    $display("STORE: new_buffer=%b, row=%d, col=%d at cycle %d, time = %t", 
                             dut.new_buffer, dut.row_count, dut.col_count, cycle_count, $time);
                end
            endcase
        end
        
        // // Monitor streaming state
        // if (dut.state == 2'b10 && dut.streaming_active) begin // STREAM_OUT
        //     if (dut.result_valid) begin
        //         $display("STREAM: addr=%d, result=%d at cycle %d", 
        //                  dut.stream_addr, result, cycle_count);
        //     end
        // end
    end
    
    // Function to convert state to string
    function [63:0] state_name;
        input [1:0] state;
        begin
            case (state)
                2'b00: state_name = "IDLE";
                2'b01: state_name = "PROCESS";
                2'b10: state_name = "STREAM";
                2'b11: state_name = "COMPLETE";
                default: state_name = "UNKNOWN";
            endcase
        end
    endfunction
    
    // Function to convert process state to string
    function [63:0] process_name;
        input [1:0] process_state;
        begin
            case (process_state)
                2'b00: process_name = "LOAD";
                2'b01: process_name = "SHIFT";
                2'b10: process_name = "CONVOLVE";
                2'b11: process_name = "STORE";
                default: process_name = "UNKNOWN";
            endcase
        end
    endfunction
    
    // Detect potential stalls
    reg [31:0] stall_counter = 0;
    reg [1:0] last_state = 0;
    reg [1:0] last_process_state = 0;
    
    always @(posedge clk) begin
        if (dut.state == last_state && dut.process_state == last_process_state && 
            dut.row_count == last_row_count && dut.col_count == last_col_count) begin
            stall_counter <= stall_counter + 1;
            
            // Report stall every 1000 cycles
            if (stall_counter == 1000) begin
                $display("WARNING: Potential stall detected at cycle %d", cycle_count);
                $display("  State: %s, Process: %s, Row: %d, Col: %d", 
                         state_name(dut.state), process_name(dut.process_state),
                         dut.row_count, dut.col_count);
                $display("  Signals: load_en=%b, loaded=%b, new_buffer=%b", 
                         dut.load_en, dut.loaded, dut.new_buffer);
                stall_counter <= 0;
            end
        end else begin
            stall_counter <= 0;
            last_state <= dut.state;
            last_process_state <= dut.process_state;
        end
    end
    
    // Optional: Dump waveforms
    initial begin
        $dumpfile("convolution_test.vcd");
        $dumpvars(0, top_tb);
    end

endmodule