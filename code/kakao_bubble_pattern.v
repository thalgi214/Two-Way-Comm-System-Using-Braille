// =============================================================================
// Module Name: kakao_bubble_pattern
// Description:
//      - 카카오톡 로고
//      - 좌표를 입력받아, 좌표에 해당하는 rgb값을 출력
// =============================================================================

`timescale 1ns / 1ps
module kakao_bubble_pattern (
    input  wire [10:0] x,        // 0~799
    input  wire [9:0]  y,        // 0~479
    input  wire        video_on,
    output reg  [7:0]  tft_r,
    output reg  [7:0]  tft_g,
    output reg  [7:0]  tft_b
);
    // 바탕색
    localparam [7:0] Y_R = 8'd255,
                     Y_G = 8'd255,
                     Y_B = 8'd0;
    // 로고 색
    localparam [7:0] B_R = 8'd163,
                     B_G = 8'd92,
                     B_B = 8'd0;

    localparam integer MAIN_X_L = 241;
    localparam integer MAIN_X_R = 559;
    localparam integer MAIN_Y_T = 180;
    localparam integer MAIN_Y_B = 300;

    localparam integer TAIL_X_L = 283;
    localparam integer TAIL_X_R = 357;
    localparam integer TAIL_Y_T = 301;
    localparam integer TAIL_Y_B = 337;

    // 카카오톡 로고의 몸체 부분
    wire in_main =
        (x >= MAIN_X_L) && (x <= MAIN_X_R) &&
        (y >= MAIN_Y_T) && (y <= MAIN_Y_B);
    
    // 카카오톡 로고의 꼬리 부분
    wire in_tail =
        (x >= TAIL_X_L) && (x <= TAIL_X_R) &&
        (y >= TAIL_Y_T) && (y <= TAIL_Y_B);
    
    // 현재 좌표가 카카오톡 로고 내부에 있는지에 대한 여부
    wire in_bubble = in_main || in_tail;

    always @* begin
        if (!video_on) begin
            tft_r = 0;
            tft_g = 0;
            tft_b = 0;
        end
        else if (in_bubble) begin
            tft_r = B_R;
            tft_g = B_G;
            tft_b = B_B;
        end
        else begin
            tft_r = Y_R;
            tft_g = Y_G;
            tft_b = Y_B;
        end
    end
endmodule
