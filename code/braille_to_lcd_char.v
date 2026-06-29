// =============================================================================
// Module Name: braille_to_lcd_char
// Description:
//      - 6비트 점자 신호(braille)을 입력
//      - text lcd가 인식할 수 있는 8비트 신호(lcd_data)로 변환해 출력
//      - braille = {dot6, dot5, dot4, dot3, dot2, dot1}
// =============================================================================


`timescale 1ns / 1ps
module braille_to_lcd_char (
    input  wire [5:0] braille,
    output reg  [7:0] lcd_data   // Text LCD에 연결할 값
);
    always @(*) begin
        case (braille)
            6'b001100 : lcd_data = 8'b0011_1010; // ":"
            6'b000000 : lcd_data = 8'b0010_0000; // " "
            6'b000001 : lcd_data = 8'b0110_0001; // a
            6'b000011 : lcd_data = 8'b0110_0010; // b
            6'b001001 : lcd_data = 8'b0110_0011; // c 
            6'b011001 : lcd_data = 8'b0110_0100; // d 
            6'b010001 : lcd_data = 8'b0110_0101; // e 
            6'b001011 : lcd_data = 8'b0110_0110; // f 
            6'b011011 : lcd_data = 8'b0110_0111; // g 
            6'b010011 : lcd_data = 8'b0110_1000; // h 
            6'b001010 : lcd_data = 8'b0110_1001; // i 
            6'b011010 : lcd_data = 8'b0110_1010; // j 
            6'b000101 : lcd_data = 8'b0110_1011; // k 
            6'b000111 : lcd_data = 8'b0110_1100; // l 
            6'b001101 : lcd_data = 8'b0110_1101; // m 
            6'b011101 : lcd_data = 8'b0110_1110; // n 
            6'b010101 : lcd_data = 8'b0110_1111; // o 
            6'b001111 : lcd_data = 8'b0111_0000; // p 
            6'b011111 : lcd_data = 8'b0111_0001; // q 
            6'b010111 : lcd_data = 8'b0111_0010; // r 
            6'b001110 : lcd_data = 8'b0111_0011; // s 
            6'b011110 : lcd_data = 8'b0111_0100; // t 
            6'b100101 : lcd_data = 8'b0111_0101; // u 
            6'b100111 : lcd_data = 8'b0111_0110; // v 
            6'b111010 : lcd_data = 8'b0111_0111; // w 
            6'b101101 : lcd_data = 8'b0111_1000; // x 
            6'b111101 : lcd_data = 8'b0111_1001; // y 
            6'b110101 : lcd_data = 8'b0111_1010; // z 

            default   : lcd_data = 8'b0010_0000; // 등록되지 않은 점자 정보이면 space(' ')
        endcase
    end
endmodule