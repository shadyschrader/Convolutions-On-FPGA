module convolve #(
    parameter IMAGE_WIDTH = 128,
    parameter IMAGE_HEIGHT = 128,
    parameter OUT = IMAGE_HEIGHT - FILTER_SIZE + 1,
    parameter FILTER_SIZE = 3
)(
    input wire clk,
    input wire rst,
    input wire mult_en, // goes high when the window_valid is high in shift module
    input wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] window_in, //3x3 window after shift
    input wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] filter_flat,
    output reg [31:0] result,
    output reg result_valid, // if result_valid is high the result gets stored
    output reg shift_buffer // if shift_buffer is high then the shift module shifts the buffer
);

// Internal registers
reg [15:0] mult_result;
reg [1:0] compute_state;
reg [3:0] compute_counter; // Counter for multi-cycle computation

// States for computation
parameter IDLE = 2'b00,
          COMPUTING = 2'b01,
          DONE = 2'b10;

// Reconstruct arrays from flat data for easier processing
wire [7:0] window [0:FILTER_SIZE-1][0:FILTER_SIZE-1];
wire [7:0] filter [0:FILTER_SIZE-1][0:FILTER_SIZE-1];

//// Extract window and filter values from flat arrays
//genvar gi1, gj1, gi2, gj2;
//generate
//    for (gi1 = 0; gi1 < FILTER_SIZE; gi1 = gi1 + 1) begin: win_rows
//        for (gj1 = 0; gj1 < FILTER_SIZE; gj1 = gj1 + 1) begin: win_cols
//            assign window[gi1][gj1] = window_in[(gi1*FILTER_SIZE+gj1)*8 +: 8];
//        end
//    end
//    for (gi2 = 0; gi2 < FILTER_SIZE; gi2 = gi2 + 1) begin: fil_rows
//        for (gj2 = 0; gj2 < FILTER_SIZE; gj2 = gj2 + 1) begin: fil_cols
//            assign filter[gi2][gj2] = filter_flat[(gi2*FILTER_SIZE+gj2)*8 +: 8];
//        end
//    end
//endgenerate

// Window Assignment
assign window[0][0] = window_in[7:0];
assign window[0][1] = window_in[15:8];
assign window[0][2] = window_in[23:16];
assign window[1][0] = window_in[31:24];
assign window[1][1] = window_in[39:32];
assign window[1][2] = window_in[47:40];
assign window[2][0] = window_in[55:48];
assign window[2][1] = window_in[63:56];
assign window[2][2] = window_in[71:64];

// Filter Assignment
assign filter[0][0] = filter_flat[7:0];
assign filter[0][1] = filter_flat[15:8];
assign filter[0][2] = filter_flat[23:16];
assign filter[1][0] = filter_flat[31:24];
assign filter[1][1] = filter_flat[39:32];
assign filter[1][2] = filter_flat[47:40];
assign filter[2][0] = filter_flat[55:48];
assign filter[2][1] = filter_flat[63:56];
assign filter[2][2] = filter_flat[71:64];

// Compute convolution result combinationally
reg [31:0] conv_result;
//assign conv_result = window[0][0]*filter[0][0] + window[0][1]*filter[0][1] + window[0][2]*filter[0][2] +
//                     window[1][0]*filter[1][0] + window[1][1]*filter[1][1] + window[1][2]*filter[1][2] +
//                     window[2][0]*filter[2][0] + window[2][1]*filter[2][1] + window[2][2]*filter[2][2];

always@(posedge clk) begin
    if(!rst) begin
        result <= 0;
        result_valid <= 0;
        shift_buffer <= 0;
        compute_state <= IDLE;
        compute_counter <= 0;
    end else begin
        case(compute_state)
            IDLE: begin
                result_valid <= 0;
                shift_buffer <= 0;
                if(mult_en) begin
                    compute_state <= COMPUTING;
                    compute_counter <= 0;
                    $display("CONVOLVE: Starting computation at time %t", $time);
                end
            end
            
            COMPUTING: begin
                conv_result = window[0][0]*filter[0][0] + window[0][1]*filter[0][1] + window[0][2]*filter[0][2] +
                              window[1][0]*filter[1][0] + window[1][1]*filter[1][1] + window[1][2]*filter[1][2] +
                              window[2][0]*filter[2][0] + window[2][1]*filter[2][1] + window[2][2]*filter[2][2];
                // Give a few cycles for computation to settle
                if(compute_counter < 2) begin
                    compute_counter <= compute_counter + 1;
                end else begin
                    result <= conv_result;
                    result_valid <= 1;
                    shift_buffer <= 1;
                    compute_state <= DONE;
                    $display("CONVOLVE: Computation done, result = %d at time %t", conv_result, $time);
                end
            end
            
            DONE: begin
                // Hold signals for one cycle, then return to idle
                result_valid <= 0;
                shift_buffer <= 0;
                compute_state <= IDLE;
                $display("CONVOLVE: Returning to idle at time %t", $time);
            end
        endcase
    end
end

endmodule