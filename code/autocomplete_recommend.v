// =============================================================================
// Module Name: autocomplete_recommend
// Description:
//   - word_shift_reg로부터 last_input 신호로 최근 입력받은 점자에 대한 정보를 입력
//   - last_input과 내장된 단어들을 비교
//   - 자동완성 가능한 단어가 있다면 autocomplete_able = 1을 출력
//   - 자동완성할 단어 중 아직 입력되지 않은 부분을 left_chars로 출력
// =============================================================================

`timescale 1ns / 1ps
module autocomplete_recommend #(
    parameter DATA_WIDTH = 6, // 한 점자 데이터 비트폭
    parameter CHECK_LEN  = 2, // 앞 2글자 비교
    parameter WORD_LEN   = 5  // 최대 5글자 단어 지원
)(
    input  wire [DATA_WIDTH*CHECK_LEN-1:0] last_input,     //최근 입력된 점자 데이터들

    output reg  autocomplete_able, // 내장된 단어 중 자동완성이 가능한 단어가 있는지에 대한 여부
    output reg  [DATA_WIDTH*(WORD_LEN-CHECK_LEN)-1:0] left_chars // 내장된 단어 중 자동완성 가능한 단어가 있을 경우, 해당 단어의 아직 실제로는 입력되지 않은 부분을 출력
);

    // 점자 코드 정의
    // braille = {dot6, dot5, dot4, dot3, dot2, dot1}

    localparam B_a = 6'b000001; // a 
    localparam B_b = 6'b000011; // b 
    localparam B_c = 6'b001001; // c 
    localparam B_d = 6'b011001; // d 
    localparam B_e = 6'b010001; // e 
    localparam B_f = 6'b001011; // f 
    localparam B_g = 6'b011011; // g 
    localparam B_h = 6'b010011; // h 
    localparam B_i = 6'b001010; // i 
    localparam B_j = 6'b011010; // j 
    localparam B_k = 6'b000101; // k 
    localparam B_l = 6'b000111; // l 
    localparam B_m = 6'b001101; // m 
    localparam B_n = 6'b011101; // n 
    localparam B_o = 6'b010101; // o 
    localparam B_p = 6'b001111; // p 
    localparam B_q = 6'b011111; // q 
    localparam B_r = 6'b010111; // r 
    localparam B_s = 6'b001110; // s 
    localparam B_t = 6'b011110; // t 
    localparam B_u = 6'b100101; // u
    localparam B_v = 6'b100111; // v 
    localparam B_w = 6'b111010; // w 
    localparam B_x = 6'b101101; // x 
    localparam B_y = 6'b111101; // y 
    localparam B_z = 6'b110101; // z 
    localparam B_sp= 6'b000000; // space

    // 비교 및 추천
    always @(*) begin
        // 기본값, 전부 space와 같음
        autocomplete_able = 1'b0;
        left_chars = {(DATA_WIDTH*(WORD_LEN-CHECK_LEN)){1'b0}};

        case (last_input)
            // "he" -> hello
            {B_h, B_e}: begin
                autocomplete_able = 1'b1;
                // 남은 글자 3개: l, l, o
                // MSB부터 첫 번째 남은 글자가 오도록 배치
                left_chars = {B_l, B_l, B_o}; 
            end

            // "by" -> bye (남은 글자: e , 공백, 공백)
            {B_b, B_y}: begin
                autocomplete_able = 1'b1;
                // 남은 글자 1개: e. 나머지는 0
                left_chars = {B_e, 6'b0, 6'b0}; 
            end

            // "go" -> good (남은 글자: o, d, 공백)
            {B_g, B_o}: begin
                autocomplete_able = 1'b1;
                // 남은 글자 2개: o, d, 나머지는 0
                left_chars = {B_o, B_d, 6'b0};
            end

            // "so" -> sorry (남은 글자: r, r, y)
            {B_s, B_o}: begin
                autocomplete_able = 1'b1;
                // 남은 글자 3개: r, r, y
                left_chars = {B_r, B_r, B_y};
            end

            // "lo" -> love (남은 글자: v, e, 공백)
            {B_l, B_o}: begin
                autocomplete_able = 1'b1;
                // 남은 글자 2개: v, e, 나머지는 공백
                left_chars = {B_v, B_e, 6'b0};
            end

            // "yo" -> you (남은 글자: u, 공백, 공백)
            {B_y, B_o}: begin
                autocomplete_able = 1'b1;
                // 남은 글자 1개: u, 나머지는 공백
                left_chars = {B_u, 6'b0, 6'b0};
            end

            default: begin
                // 매칭되는 앞 2글자가 없으면 아무것도 안 함
                // left_chars로 전부 공백 출력
                autocomplete_able = 1'b0;
                left_chars = 0;
            end
        endcase
    end
endmodule