`timescale 1ns / 1ps
module dec_3to8_6bit (
    input  wire [2:0] I,
    input  wire       en,
    output reg  [5:0] O
);
    always @(*) begin
        if (!en) O = 6'b000000;
        else begin
            case (I)
                3'd0:    O = 6'b000001; // seg_in[0] 대응
                3'd1:    O = 6'b000010; // seg_in[1] 대응
                3'd2:    O = 6'b000100; // seg_in[2] 대응
                3'd3:    O = 6'b001000; // seg_in[3] 대응
                3'd4:    O = 6'b010000; // seg_in[4] 대응
                3'd5:    O = 6'b100000; // seg_in[5] 대응
                default: O = 6'b000000; // 점자는 6bit -> 그 이상의 비트는 자름
            endcase
        end
    end
endmodule