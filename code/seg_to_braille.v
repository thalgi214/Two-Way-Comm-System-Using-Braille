// =============================================================================
// Module Name: seg_to_braille
// Description:
//   - 점자 입력부의 각각의 버튼에 대한 신호를 점자 신호로 변환
//   - decoder를 이용해 각각의 신호를 one-hot 신호로 변환
//   - one-hot 신호들을 adder를 이용해 합산
// =============================================================================

`timescale 1ns / 1ps
module seg_to_braille (
    input wire [5:0] seg_in,       // 물리 버튼 입력
    output wire [5:0] braille_data // 점자 출력 {dot6,dot5,dot4,dot3,dot2,dot1}
);
    //   FPGA 버튼 상의 신호 매핑    
    //    _______   _______
    //   | dot1 |   | dot4 |
    //   ￣￣￣    ￣￣￣
    //    _______   _______
    //   | dot2 |   | dot5 |
    //   ￣￣￣    ￣￣￣
    //    _______   _______
    //   | dot3 |   | dot6 |
    //   ￣￣￣    ￣￣￣
    wire dot1 = seg_in[0];
    wire dot2 = seg_in[2];
    wire dot3 = seg_in[4];
    wire dot4 = seg_in[1];
    wire dot5 = seg_in[3];
    wire dot6 = seg_in[5];

    // 각 점자를 decoder 입력으로 보내기
    // dotX == 1 일 때만 특정 비트 위치에 1을 세팅
    wire [5:0] op1, op2, op3, op4, op5, op6;

    // dot1 == 1 -> 00_00_01
    dec_3to8_6bit dec_dot1 (.I(3'd0), .en(dot1), .O(op1));

    // dot2 == 1 -> 00_00_10
    dec_3to8_6bit dec_dot2 (.I(3'd1), .en(dot2), .O(op2));

    // dot3 == 1 -> 00_01_00
    dec_3to8_6bit dec_dot3 (.I(3'd2), .en(dot3), .O(op3));

    // dot4 == 1 -> 00_10_00
    dec_3to8_6bit dec_dot4 (.I(3'd3), .en(dot4), .O(op4));

    // dot5 == 1 -> 01_00_00
    dec_3to8_6bit dec_dot5 (.I(3'd4), .en(dot5), .O(op5));

    // dot6 == 1 -> 10_00_00
    dec_3to8_6bit dec_dot6 (.I(3'd5), .en(dot6), .O(op6));

    // Adder - 6개의 op 신호를 모두 더함
    wire [5:0] sum1, sum2, sum3, sum4, sum5;
    sixbit_adder add1 (.A(op1),  .B(op2),  .c_in(1'b0), .S(sum1), .c_out(), .v());
    sixbit_adder add2 (.A(sum1), .B(op3),  .c_in(1'b0), .S(sum2), .c_out(), .v());
    sixbit_adder add3 (.A(sum2), .B(op4),  .c_in(1'b0), .S(sum3), .c_out(), .v());
    sixbit_adder add4 (.A(sum3), .B(op5),  .c_in(1'b0), .S(sum4), .c_out(), .v());
    sixbit_adder add5 (.A(sum4), .B(op6),  .c_in(1'b0), .S(braille_data), .c_out(), .v());
    // ex)
    // dot1, dot3, dot5 입력
    //      00_00_01
    //      00_01_00
    //   + 01_00_00
    // ─────────────
    //      01_01_01  -> braille_data
endmodule
