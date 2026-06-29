// =============================================================================
// Module Name: TFT_LCD_top
// Description:
//      - 카카오톡 로고 출력
//      - UI 요소
// =============================================================================

`timescale 1ns / 1ps
module TFT_LCD_top (
    input        clk,
    input        rst,

    output       dclk,
    output       hsync,   // 수평 동기 신호
    output       vsync,   // 수직 동기 신호
    output       den,     // data enable
    output       disp_en, // display enable
    output reg [7:0] R,   // RED 색상 출력값
    output reg [7:0] G,   // GREEN 색상 출력값
    output reg [7:0] B    // BLUE 색상 출력값
);

    wire [10:0] counter_h; //수평 카운터
    wire [9:0]  counter_v; //수직 카운터
    // 내부 신호
    wire        disp_den;   // Data Enable
    wire        disp_hsync; // 수평 동기 신호
    wire        disp_vsync; // 수직 동기 신호
    wire        disp_clk;   // 픽셀 클럭
    wire        disp_enb;   // Display Enable

    TFT_LCD_controller CONTROLLER (
        .clk        (clk),
        .rst        (rst),
        .counter_h  (counter_h), // 현재 수평 위치
        .counter_v  (counter_v), // 현재 수직 위치
        .disp_den   (disp_den),
        .disp_hsync (disp_hsync),
        .disp_vsync (disp_vsync),
        .disp_clk   (disp_clk),
        .disp_enb   (disp_enb)
    );

    // 내부 신호를 실제 출력 포트에 연결
    assign dclk    = disp_clk;
    assign hsync   = disp_hsync;
    assign vsync   = disp_vsync;
    assign den     = disp_den;
    assign disp_en = disp_enb;

    wire [10:0] x_addr;
    wire [9:0]  y_addr;
    
    // counter 값들을 이용해 실제 좌표값 계산
    assign x_addr = (counter_h >= 11'd211) ? (counter_h - 11'd211) : 11'd0;
    assign y_addr = (counter_v >= 10'd23)  ? (counter_v - 10'd23)  : 10'd0;

    wire video_on = disp_den; //데이터가 출력돼야 하는 구간임을 알림

    // 말풍선 패턴 모듈 
    wire [7:0] w_r, w_g, w_b;
    kakao_bubble_pattern KAKAO (
        .x        (x_addr),
        .y        (y_addr),
        .video_on (video_on),
        .tft_r    (w_r),
        .tft_g    (w_g),
        .tft_b    (w_b)
    );
    always @(*) begin
        R = w_r;
        G = w_g;
        B = w_b;
    end

endmodule