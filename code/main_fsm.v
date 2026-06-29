// =============================================================================
// Module Name: main_fsm
// Description:
//   - 각 입력 장치와 저장 장치, led_fsm과의 상호작용을 제어
// =============================================================================

`timescale 1ns / 1ps
module main_fsm #(
    //sram
    parameter DATA_WIDTH       	= 6,  	// sram의 한 cell의 bit수
    parameter ONE_LINE_WIDTH    	= 4,  	// 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
    parameter ADDR_WIDTH        	= 10, 	// sram에 점자 2^ADDR_WIDTH개 저장 가능
    //autocomplete
    parameter WORD_LEN          	= 5,  	// autocomplete recommend 모듈에 내장할 단어의 길이
    parameter CHECK_LEN         	= 2   	// 자동완성 가능 여부 판정 시 검사할, 최근 입력된 점자의 개수
)(
    input wire clk,
    input wire rst,

    // 사용자 선택
    input wire btn_user, // 발신자 toggle을 알리는 pulse 신호
    input wire user,     // 발신자(a : 0, b : 1) 에 대한 신호

    // 점자 입력 및 동작 제어
    input wire [5:0] braille_data,      		// 6비트 점자 데이터
    input wire switch_save,               	// save 동작을 알리는 pulse 신호
    input wire switch_backspace,           	// backspace 동작을 알리는 pulse 신호
    input wire switch_autocomplete,        	// autocomplete 동작 수락을 알리는 pulse 신호
    input wire switch_send,                	// send 동작을 알리는 pulse 신호
    input wire switch_autocomplete_mode,   // autocomplete_mode 진입을 알리는 flag 신호
    output reg char_saved_pulse,        	// 문자 저장 완료 신호
    
    // led fsm
    output reg start_send,    // led fsm 동작 개시 신호
    input wire send_done,     // led fsm 동작 종료
    output reg [7:0] msg_len, // led fms에 현재 line에 입력된 점자 수 제공
    
    // 자동완성
    input wire autocomplete_able,     // 내장된 단어 중 자동완성이 가능한 단어가 있는지에 대한 여부
    input wire [DATA_WIDTH*(WORD_LEN-CHECK_LEN)-1:0] left_chars, // 내장된 단어 중 자동완성 가능한 단어가 있을 경우, 해당 단어의 아직 실제로는 입력되지 않은 부분을 출력
    
    // SRAM 제어 및 출력
    output reg we,
    output wire [ADDR_WIDTH-1:0] addr,
    output reg [5:0] data_out
);
    // 상태
    localparam S_WAIT_USER              		= 4'd0;  // 발신자 정보 입력 대기
    localparam S_SAVE                   		= 4'd1;  // 입력된 점자 정보 종합 -> sram에 저장
    localparam S_BACKSPACE              		= 4'd2;  // 최근 입력된 한 개의 점자 정보 리셋
    localparam S_AUTO_COMPLETE_MODE     	= 4'd3;  // 자동완성 모드 활성화
    localparam S_AUTO_WRITE             		= 4'd4;  // 자동완성 할 단어를 순차적으로 sram에 저장
    localparam S_SEND                  			= 4'd5;  // 입력 위치를 다음 line의 첫번째 칸으로 이동
    localparam S_WAIT_DISPLAY           		= 4'd7;  // led fsm의 동작을 대기
    localparam S_SAVE0                  		= 4'd8;  // sram에 발신자 정보 입력
    localparam S_SAVE1                  		= 4'd9;  // sram에 ":" 입력
    localparam S_WAIT_BRAILLE           		= 4'd10; // 점자 정보의 입력 대기

    // 카운터 명령어
    localparam CMD_IDLE      		= 3'b000;
    localparam CMD_SPACE     	= 3'b001; // 주소 증가
    localparam CMD_BACKSPACE 	= 3'b010; // 주소 감소
    localparam CMD_SEND      	= 3'b011; // 줄 바꿈

    // autowrite 시 직접 sram에 입력해야 할 단어 길이 계산
    localparam AUTO_LEN = WORD_LEN - CHECK_LEN; 

    reg [3:0] state, next_state; 
    wire [ADDR_WIDTH-1:0] w_word_cnt; 
    reg [2:0] cmd;    

    reg [2:0] auto_write_cnt;    // 현재 몇 번째 글자 쓰는 중인지
    
    // 남은 글자들을 캡처하기 위한 레지스터
    // autowrite로 단어들을 새롭게 sram에 저장하면 최근 입력된 점자 정보도 갱신되기 때문
    reg [DATA_WIDTH*(WORD_LEN-CHECK_LEN)-1:0] captured_auto_data; 

    // sram에 저장할 주소 설정
    // Backspace 시 현재 커서의 바로 앞칸을 지워야 함
    assign addr = (state == S_BACKSPACE) ? (w_word_cnt - 1'b1) : w_word_cnt;
    // 현재 line의 몇번째 칸에 있는지에 대한 정보. msg_len(현재 line의 점자 개수) 계산에 이용됨
    wire [ONE_LINE_WIDTH-1:0] line_cursor; assign line_cursor = w_word_cnt[ONE_LINE_WIDTH-1:0];

    // Counter 인스턴스
    // main fsm에서 현재 동작에 해당하는 cmd 신호 counter에 전달
    // counter에서 현재 동작에 맞게 w_word_cnt을 갱신
    // main fsm에서 w_word_cnt를 토대로 sram의 addr 제어
    Counter_main COUNTER (
        .clk(clk),
        .rst(rst),
        .cmd(cmd), 
        .addr(w_word_cnt)  
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 초기화
            state <= S_WAIT_USER;
            auto_write_cnt <= 0;
            captured_auto_data <= 0;
        end
        else begin
            state <= next_state;
            if (state == S_AUTO_COMPLETE_MODE && switch_autocomplete && autocomplete_able) begin
                captured_auto_data <= left_chars; //현재 left_chars를 캡쳐
                auto_write_cnt <= 0; // auto_write_cnt 초기화. 1씩 늘려가며 captured_auto_data의 점자들을 하나씩 sram에 저장하기 위함 
            end
            else if (state == S_AUTO_WRITE) begin
                auto_write_cnt <= auto_write_cnt + 1; // auto_write_cnt 1 증가, captured_auto_data의 다음 점자를 sram에 저장
            end
        end
    end

    // WORD_LEN=5, CHECK_LEN=2일 때를 기준으로 설계
    always @* begin
        //기본값
        we = 0;
        data_out = 0;
        char_saved_pulse = 0;
        start_send = 0;
        msg_len = 0;
        cmd = CMD_IDLE;

        case (state)
            S_WAIT_USER: begin end

            S_SAVE: begin 
                // 메모리 꽉 차지 않았을 때만 저장
                if (w_word_cnt < ({ADDR_WIDTH{1'b1}})) begin
                    data_out = braille_data; 	//sram에 braille_data 저장
                    we = 1;                  	//sram에 write
                    cmd = CMD_SPACE;         //counter에 CMD_SPACE 명령
                    char_saved_pulse = 1;    	// 문자 저장 완료 신호
                end
            end

            S_BACKSPACE: begin 
                cmd = CMD_BACKSPACE;   //counter에 CMD_BACKSPACE 명령
                we = 1;                		//sram에 write
                data_out = 6'b000000;  		// 0으로 리셋
                char_saved_pulse = 1;  		// 문자 저장 완료 신호
            end

            S_AUTO_WRITE: begin
                we = 1;               	 // sram에 write
                cmd = CMD_SPACE;      // counter에 CMD_SPACE 명령
                char_saved_pulse = 1;  	// 문자 저장 완료 신호

                // auto_write_cnt를 1씩 늘려가며 captured_auto_data의 점자들을 순차적으로 sram에 저장.
                // 이 때 sram 에 저장될 data를 현재 auto_write_cnt를 바탕으로 할당
                case (auto_write_cnt) 
                    3'd0: data_out = captured_auto_data[DATA_WIDTH*3 - 1 : DATA_WIDTH*2];
                    3'd1: data_out = captured_auto_data[DATA_WIDTH*2 - 1 : DATA_WIDTH*1];
                    3'd2: data_out = captured_auto_data[DATA_WIDTH*1 - 1 : 0];
                    default: data_out = {DATA_WIDTH{1'b0}}; // DATA_WIDTH 길이만큼 0으로 채움
                endcase
            end
            
            S_SEND: begin 
                start_send = 1; //led fsm 동작 시작 신호
                // 전송 길이 계산 (발신자 정보, " "을 구성하는 2칸 제외)
                if (line_cursor >= 2) msg_len = line_cursor - 2; else msg_len = 0;
                cmd = CMD_SEND;         	// counter에 CMD_SEND 명령
                char_saved_pulse = 1;   	// 문자 저장 완료 신호
            end

            S_WAIT_DISPLAY: begin
                char_saved_pulse = 1; // 문자 저장 완료 신호
            end

            S_SAVE0 : begin
                we = 1;                         		// sram에 write
                if (user) data_out = 6'b000011; 	// 발신자가 b이면 b에 해당하는 점자 정보 sram에 저장
                else      data_out = 6'b000001; 	// 발신자가 a이면 a에 해당하는 점자 정보 sram에 저장
                cmd = CMD_SPACE;                	// counter에 CMD_SPACE 명령
                char_saved_pulse = 1;           	// 문자 저장 완료 신호
            end

            S_SAVE1 : begin
                we = 1;                 		// sram에 write
                data_out = 6'b00_11_00; 	// ":"에 해당하는 점자 정보 sram에 저장
                cmd = CMD_SPACE;        	// counter에 CMD_SPACE 명령
            end
            
            default: ;
        endcase
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_WAIT_USER: begin
                //save 동작 시 S_SAVE0으로.
                if (switch_save) next_state = S_SAVE0;
            end

            // S_SAVE0 -> S_SAVE1 -> S_WAIT_BRAILLE

            S_SAVE0 : next_state = S_SAVE1; 
            S_SAVE1 : next_state = S_WAIT_BRAILLE; 

            // S_WAIT_BRAILLE 	-> send 동작 시              		-> S_SEND
            //                		-> autocomplete_mode 진입 시 	-> S_AUTO_COMPLETE_MODE
            //                		-> save 동작 시             		-> S_SAVE
            //               		-> backspace 동작 시         		-> S_BACKSPACE

            S_WAIT_BRAILLE: begin
                if      (switch_send) next_state = S_SEND;
                else if (switch_autocomplete_mode) next_state = S_AUTO_COMPLETE_MODE;
                else if (switch_save) begin
                    if (line_cursor < (1 << ONE_LINE_WIDTH) - 1) next_state = S_SAVE; //해당 line에 입력할 공간이 남은 경우에만 save
                    else next_state = S_WAIT_BRAILLE;  
                end
                else if (switch_backspace) begin
                    if (line_cursor > 2) next_state = S_BACKSPACE; // 해당 line에 이미 입력된 점자가 있을 경우에만 backspace 가능
                    else next_state = S_WAIT_BRAILLE;  
                end
            end
            
            // S_AUTO_COMPLETE_MODE 	-> switch_autocomplete_mode가 꺼지면 				-> S_WAIT_BRAILLE
            //                      			-> 자동완성 가능한 단어가 있고 && 자동완성 수락 동작 시 	-> S_AUTO_WRITE

            S_AUTO_COMPLETE_MODE: begin
                if (!switch_autocomplete_mode) begin
                    next_state = S_WAIT_BRAILLE;
                end
                else if (switch_autocomplete && autocomplete_able) begin
                    next_state = S_AUTO_WRITE;
                end
                else begin
                    next_state = S_AUTO_COMPLETE_MODE;
                end
            end

            // S_AUTO_WRITE 	-> 자동완성 단어를 sram에 다 저장했으면 -> S_AUTO_COMPLETE_MODE
            //              		-> 다 저장 못했으면 				-> S_AUTO_WRITE

            S_AUTO_WRITE: begin
                if (auto_write_cnt >= AUTO_LEN - 1) begin //sram에 저장해야 할 점자 다 저장했으면
                    next_state = S_AUTO_COMPLETE_MODE; // 다시 자동완성 대기로
                end
                else begin
                    next_state = S_AUTO_WRITE; // 다음 칸의 점자를 sram에 저장
                end
            end

            // S_SAVE       		-> S_WAIT_BRAILLE
            // S_BACKSPACE  	-> S_WAIT_BRAILLE
            // S_SEND       	-> S_WAIT_DISPLAY -> led fsm이 끝나면 -> S_WAIT_USER

            S_SAVE:          	next_state = S_WAIT_BRAILLE;
            S_BACKSPACE:     	next_state = S_WAIT_BRAILLE;
            S_SEND:          	next_state = S_WAIT_DISPLAY;
            S_WAIT_DISPLAY: begin
                if (send_done) next_state = S_WAIT_USER; 
                else next_state = S_WAIT_DISPLAY;
            end
            default: next_state = S_WAIT_USER;
        endcase
    end

endmodule