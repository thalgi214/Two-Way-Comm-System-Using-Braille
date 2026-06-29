// =============================================================================
// Module Name: TFT_LCD_controller
// Description:
//   - TFT-LCD 구동을 위한 타이밍 제어기
// =============================================================================

`timescale 1ns / 1ps
module TFT_LCD_controller #(
    parameter HSIZE = 11, // 수평 카운터 비트 수
    parameter VSIZE = 10  // 수직 카운터 비트 수
)(
    input  clk,
    input  rst,

    // 현재 스캔 중인 픽셀의 좌표
    output reg [HSIZE-1:0] counter_h,
    output reg [VSIZE-1:0] counter_v,

    output reg  disp_den,   // Data Enable
    output reg  disp_hsync, // 수평 동기 신호
    output reg  disp_vsync, // 수직 동기 신호
    output      disp_clk,   // 픽셀 클럭
    output      disp_enb    // display enable
); 

    reg video_on_h, video_on_v; // 디스플레이에 데이터를 표시할지의 여부

    assign disp_clk = clk;  // 입력 클럭을 그대로 픽셀 클럭으로 사용
    assign disp_enb = 1'b1; // 디스플레이를 항상 켜둠

    always @(posedge rst or posedge clk) begin
        if (rst) begin
            counter_h <= 'd0;
            counter_v <= 'd0;
        end
        else begin
            // 수평 카운터 : 0 ~ 1055
            if (counter_h >= 'd1055) begin
                counter_h <= 'd0;
                // 수직 카운터 : 한 줄 스캔 완료 시 증가
                if (counter_v >= 'd524)
                    counter_v <= 'd0; // 마지막 라인 도달 시 0으로 리셋
                else
                    counter_v <= counter_v + 'd1;
            end
            else
                counter_h <= counter_h + 'd1;
        end
    end

    always @(posedge rst or posedge clk) begin
        if (rst) begin
            disp_hsync <= 'd0;
            disp_vsync <= 'd0;
        end
        else begin
            // counter_h 는 끝(1055) 에서 1클럭동안 low
            if (counter_h == 'd1055)
                disp_hsync <= 'd0;
            else
                disp_hsync <= 'd1;

            // counter_v 는 끝(525) 에서 1클럭동안 low
            if (counter_v == 'd525)
                disp_vsync <= 'd0;
            else
                disp_vsync <= 'd1;
        end
    end

    always @(posedge rst or posedge clk) begin
        if (rst) begin
            video_on_h <= 'd0;
            video_on_v <= 'd0;
            disp_den   <= 'd0;
        end
        else begin
            // Horizontal : 211 ~ 1010에서 active
            if ((counter_h <= 'd1010) && (counter_h > 'd210))
                video_on_h <= 'd1;
            else
                video_on_h <= 'd0;

            // Vertical : 23 ~ 502 에서 active
            if ((counter_v <= 'd502) && (counter_v > 'd22))
                video_on_v <= 'd1;
            else
                video_on_v <= 'd0;

            // video_on_h, video_on_v가 모두 active일 때만 데이터 출력
            disp_den <= video_on_h & video_on_v;
        end
    end

endmodule
