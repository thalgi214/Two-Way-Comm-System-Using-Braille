// =============================================================================
// Module Name: btn_top_controller
// Description:
//   - 점자 입력부 6개, 사용자 toggle 버튼 1개 제어
//   - 입력 신호를 디바운싱
//   - 발신자가 save를 누르기 이전의 모든 신호를 누적
// =============================================================================

`timescale 1ns / 1ps
module btn_top_controller #(
    parameter FILTERINGTIME = 20
)(
    input wire clk,
    input wire rst,
    input wire char_saved_pulse, 
    
    // 점자 입력
    input wire btn_a_input,
    input wire btn_b_input,
    input wire btn_c_input,
    input wire btn_d_input,
    input wire btn_e_input,
    input wire btn_f_input,
    
    // 발신자 toggle
    input wire btn_g_input,

    output reg user,        		// 발신자(a : 0, b : 1) 에 대한 신호
    output reg btn_user,    		// 발신자 toggle을 알리는 신호
    output wire [5:0] braille_data 	//입력된 점자에 대한 6비트 데이터
);

    // 입력 통합 및 디바운싱
    // 총 7개 버튼 (a~g)
    // - 아직 debounced 되지 않은 버튼 신호
    wire [6:0] not_debounced_btns;
    assign not_debounced_btns = 
    {btn_g_input, btn_f_input, 
    btn_e_input, btn_d_input, 
    btn_c_input, btn_b_input, 
    btn_a_input};

    // - debounced된 버튼 신호
    wire [6:0] debounced_btns;

    genvar i;
    generate //각 btn 신호에 debouncer 연결
        for (i = 0; i < 7; i = i + 1) begin : gen
            debouncer #(
                .FILTERINGTIME(FILTERINGTIME)
            ) BUTTON_DEBOUNCER (
                .clk(clk), 
                .rst(rst), 
                .not_debounced_signal(not_debounced_btns[i]), 
                .debounced_signal(debounced_btns[i])
            );
        end
    endgenerate

    // 버튼 신호를 pulse 신호로 변환 
    // 신호가 0->1로 변하는 순간만 btn_posedge가 1
    reg [6:0] prev_debounced_btns;
    wire [6:0] btn_posedge; assign btn_posedge = debounced_btns & ~prev_debounced_btns;    
    always @(posedge clk or posedge rst) begin
        if (rst) begin //초기화
            prev_debounced_btns <= 7'b0; 
        end else begin
            prev_debounced_btns <= debounced_btns;
        end
    end

    // 출력
    reg [5:0] Seg;
    always @(posedge clk or posedge rst) begin
        if (rst) begin //초기화
            user <= 1'b0;
            btn_user <= 1'b0;
            Seg <= 6'b0;
        end
        else begin
            if (char_saved_pulse) begin
                //한 점자를 save 완료 시 모듈에 저장된 점자 정보 초기화, 새로운 점자 입력 개시
                btn_user <= 1'b0;
                Seg  <= 6'b0; 
            end
            else begin
                // 버튼 g -> user toggle
                if (btn_posedge[6]) begin
                    user <= ~user;    // 토글 동작
                    btn_user <= 1'b1;
                end

                // 버튼 a~f -> 점자 입력
                // save 동작 이전에 눌린 모든 버튼들의 신호를 1로 올림.
                if (btn_posedge[0]) Seg[0] <= 1'b1; // btn_a
                if (btn_posedge[1]) Seg[1] <= 1'b1; // btn_b
                if (btn_posedge[2]) Seg[2] <= 1'b1; // btn_c
                if (btn_posedge[3]) Seg[3] <= 1'b1; // btn_d
                if (btn_posedge[4]) Seg[4] <= 1'b1; // btn_e
                if (btn_posedge[5]) Seg[5] <= 1'b1; // btn_f
            end
        end
    end

    // 점자 입력에 대한 신호들을 종합해 6비트 점자 신호로 변환
    seg_to_braille CONVERTER (
        .seg_in(Seg),
        .braille_data(braille_data)
    );

endmodule