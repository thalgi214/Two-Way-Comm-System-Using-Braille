// =============================================================================
// Module Name: word_shift_reg
// Description:
//   - 입력되는 점자들을 Data_in으로 입력
//   - 최근 입력받은 점자들을 Last_input로 병렬 출력
//   - shift register의 구조
// =============================================================================

`timescale 1ns / 1ps
module word_shift_reg #(
    parameter DATA_WIDTH = 6, 	//한 점자 data의 비트 수
    parameter CHECK_LEN  = 2  	// 검사할 글자 수
)(
    input  wire clk,
    input  wire rst,

    // 입력 인터페이스
    input  wire switch_save,                 		// save 동작을 알리는 pulse 신호
    input  wire [DATA_WIDTH-1:0] data_in,    	// 입력된 점자 데이터
    input  wire switch_backspace,           	 	// backspace 동작을 알리는 pulse 신호
    input  wire switch_send,                 		// send 동작을 알리는 pulse 신호

    //최근 입력된 점자 데이터들을 병렬로 출력
    // N=2일 때 [11:6]은 이전 글자, [5:0]은 최신 글자
    output reg [DATA_WIDTH*CHECK_LEN-1:0] last_input
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            //초기화
            last_input <= {(DATA_WIDTH*CHECK_LEN){1'b0}};
        end
        else if (switch_send) begin
            // send 스위치 on 시 모든 데이터 리셋
            last_input <= {(DATA_WIDTH*CHECK_LEN){1'b0}};
        end
        else if (switch_backspace) begin
            // backspace 스위치 on 시
            // 최근 입력된 점자 삭제, 6bit씩 right shift
            // 가장 오래된 점자의 자리는 0으로 채워짐
            // ex) [A, B] -> Backspace -> [0, A]
            last_input <= last_input >> DATA_WIDTH;
        end
        else if (switch_save) begin 
            // save 스위치 on 시
            // 기존 데이터를 6bit left shift
            // 가장 하위 6비트 점자에 새 점자 데이터를 채움
            // ex) [A, B] -> 점자 C 입력 후 save -> [B, C]
            last_input <= {last_input[DATA_WIDTH*(CHECK_LEN-1)-1 : 0], data_in};
        end
    end
endmodule