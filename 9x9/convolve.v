module convolve #(
    parameter IMAGE_WIDTH = 9,
    parameter IMAGE_HEIGHT = 9,
    parameter OUT = IMAGE_HEIGHT - FILTER_SIZE + 1,
    parameter FILTER_SIZE = 3
)(
    input wire clk,
    input wire rst,
    input wire mult_en,     // goes high when the window_valid is high in shift module
    input wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] window_in,                   //3x3 window after shift
    input wire [(FILTER_SIZE*FILTER_SIZE*8)-1:0] filter_flat,
    output reg [15:0] result,
    output reg result_valid,     // if result_valid is high the result gets stored
    output reg shift_buffer         // if shift_buffer is high then the shift module shifts the buffer
);

    // Internal registers
    reg [15:0] mult_result;
    reg computing;  // Validates whenever the convolution has to be started
    
    // Reconstruct arrays from flat data for easier processing
    wire [7:0] window [0:FILTER_SIZE-1][0:FILTER_SIZE-1];
    wire [7:0] filter [0:FILTER_SIZE-1][0:FILTER_SIZE-1];


    // Extract window and filter values from flat arrays
    genvar gi1, gj1, gi2, gj2; 

    generate
        for (gi1 = 0; gi1 < FILTER_SIZE; gi1 = gi1 + 1) begin: win_rows
            for (gj1 = 0; gj1 < FILTER_SIZE; gj1 = gj1 + 1) begin: win_cols
                assign window[gi1][gj1] = window_in[(gi1*FILTER_SIZE+gj1)*8 +: 8];
            end
        end

        for (gi2 = 0; gi2 < FILTER_SIZE; gi2 = gi2 + 1) begin: fil_rows
            for (gj2 = 0; gj2 < FILTER_SIZE; gj2 = gj2 + 1) begin: fil_cols
                assign filter[gi2][gj2] = filter_flat[(gi2*FILTER_SIZE+gj2)*8 +: 8];
            end
        end
    endgenerate


    integer i, j;
    

    always@(posedge clk or negedge rst)begin
        if(!rst)begin
            mult_result <= 0;
            result <= 0;
            result_valid <= 0;
            shift_buffer <= 0;
            computing <= 0;
        end else if(mult_en && !computing) begin
            computing <= 1;
            shift_buffer <= 0;
            mult_result <= 0;
        end else if(/*mult_en && */computing)begin
            mult_result = 0;

            for (i = 0; i<FILTER_SIZE ; i=i+1) begin
                for (j = 0; j<FILTER_SIZE ; j=j+1 ) begin
                    mult_result = mult_result + window[i][j]*filter[i][j];
                end
            end
            
            result <= mult_result;
            computing <= 0;
            shift_buffer <= 1;
            result_valid <= 1;

            
        end else begin
            shift_buffer <= 0;
            result_valid <= 0;
        end
    end  

endmodule