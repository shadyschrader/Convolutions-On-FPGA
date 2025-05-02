module load #(
  parameter IMAGE_WIDTH = 128,
  parameter IMAGE_HEIGHT = 128,
  parameter FILTER_SIZE = 3
) (
  input clk,
  input rst,
  input wire load_en,
  input wire new_buffer,
  // BRAM interface instead of direct image input
  output reg bram_en_b,
  output reg [($clog2(IMAGE_HEIGHT*IMAGE_WIDTH))-1:0] bram_addr_b,
  input wire [7:0] bram_data_b,
  input wire [15:0] row_count,  // Get row count from top module
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
  reg [$clog2(FILTER_SIZE*IMAGE_WIDTH):0] load_counter;
  parameter IDLE = 2'b00, LOADING_BUFFER = 2'b01, READ_WAIT = 2'b10, DONE = 2'b11;
  
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      for (i = 0; i < FILTER_SIZE; i = i + 1) begin
        for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
          row_buffer_internal[i][j] <= 0;
        end
      end
      loaded <= 0;
      load_state <= IDLE;
      load_counter <= 0;
      bram_en_b <= 0;
      bram_addr_b <= 0;
    end else begin
      case (load_state)
        IDLE: begin
          if (load_en) begin
            // Start loading from BRAM to buffer
            load_state <= LOADING_BUFFER;
            load_counter <= 0;
            bram_en_b <= 1;
            loaded <= 0;
          end
        end
        
        LOADING_BUFFER: begin
          // Calculate row and column from counter
          i = load_counter / IMAGE_WIDTH;
          j = load_counter % IMAGE_WIDTH;
          
          // Set address to read from BRAM based on row_count
          bram_addr_b <= (row_count + i) * IMAGE_WIDTH + j;
          
          // Wait one cycle for BRAM data
          load_state <= READ_WAIT;
        end
        
        READ_WAIT: begin
          // Capture data from BRAM
          row_buffer_internal[load_counter/IMAGE_WIDTH][load_counter%IMAGE_WIDTH] <= bram_data_b;
          
          if (load_counter == FILTER_SIZE*IMAGE_WIDTH-1) begin
            load_state <= DONE;
            bram_en_b <= 0;
          end else begin
            load_counter <= load_counter + 1;
            load_state <= LOADING_BUFFER;
          end
        end
        
        DONE: begin
          loaded <= 1;
          if (!load_en && !new_buffer) begin
            load_state <= IDLE;
            loaded <= 0;
          end
        end
      endcase
    end
  end
endmodule