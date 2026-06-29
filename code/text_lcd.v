// =============================================================================
// Module Name: text_lcd
// Description:
//     - 점자 입력 결과를 문자 형태로 표시하는 출력 장치
//     - sram에 저장된 점자 신호를 이전 line의 첫번째 칸부터 순차적으로 read
//     - autocomplete_able == 1이라면 자동완성 가능한 단어(left_chars)를 문장의 마지막에 출력
// =============================================================================

`timescale 1ns / 1ps
module text_lcd #(
    // sram
    parameter DATA_WIDTH        = 6, 	// sram의 한 cell의 bit수
    parameter ONE_LINE_WIDTH    = 4, 	// 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
    parameter ADDR_WIDTH        = 10, 	// sram에 점자 2^ADDR_WIDTH개 저장 가능

    // autocomplete
    parameter WORD_LEN          = 5, 	// autocomplete recommend 모듈에 내장할 단어의 길이
    parameter CHECK_LEN         = 2  	// 자동완성 가능 여부 판정 시 검사할, 최근 입력된 점자의 개수
)(
    input wire clk,
    input wire rst,
    
    // main fsm
    input wire [ADDR_WIDTH-1:0] cur_addr, // 현재 main fsm의 addr

    // autocomplete recommend
    input wire autocomplete_able, 							//자동완성 가능한 단어가 있는지에 대한 여부
    input wire [DATA_WIDTH*(WORD_LEN-CHECK_LEN)-1:0] left_chars, 	//자동완성 가능한 단어 중 아직 실제로는 입력되지 않는 점자에 대한 데이터 

    // sram
    output reg [ADDR_WIDTH-1:0] sram_rd_addr, 
    input wire [DATA_WIDTH-1:0] sram_rd_data, 

    // 실제 lcd와 연결
    output wire lcd_enb,
    output reg lcd_rs, lcd_rw,
    output reg [7:0] lcd_data
);
    
    // 클럭 분주기
    reg [24:0] clk_div; 
    always @(posedge clk or posedge rst) begin
        if (rst) 
            clk_div <= 25'd0;
        else 
            clk_div <= clk_div + 1;
    end
    wire lcd_slow_clk = clk_div[16];

    // 점멸 효과를 위한 신호
    wire blink_on = clk_div[24];

    // 내부 신호 정의
    reg [3:0] state;
    integer counter;

    // 실습에서 이용한 코드 구조 이용
    localparam delay          	= 3'b000;
    localparam function_set   	= 3'b001;
    localparam entry_mode     = 3'b010;
    localparam display_onoff  	= 3'b011;
    localparam line1          	= 3'b100;
    localparam line2          	= 3'b101;
    localparam delay_t        	= 3'b110;
    localparam clear_display  	= 3'b111;

    wire [7:0] w_ascii_data;            		// 점자를 아스키 신호로 변환한 신호
    wire [7:0] w_left_chars_decoded2;   	// 자동완성 1번째 점자
    wire [7:0] w_left_chars_decoded1;   	// 자동완성 2번째 점자
    wire [7:0] w_left_chars_decoded0;   	// 자동완성 3번째 점자


    // sram에서 addr에 해당하는 6비트 점자 data를 lcd에 적용할 수 있는 8비트 아스키 신호로 변환
    braille_to_lcd_char CONVERTER1 (
        .braille(sram_rd_data),
        .lcd_data(w_ascii_data)
    );

    // 자동완성할 점자 3개 병렬 연결
    // left_chars[17:12] -> 첫 번째 점자
    braille_to_lcd_char CONVERTER2 (
        .braille(left_chars[17:12]),
        .lcd_data(w_left_chars_decoded2)
    );

    // left_chars[11:6] -> 두 번째 점자
    braille_to_lcd_char CONVERTER3 (
        .braille(left_chars[11:6]),
        .lcd_data(w_left_chars_decoded1)
    );

    // left_chars[5:0] -> 세 번째 점자
    braille_to_lcd_char CONVERTER4 (
        .braille(left_chars[5:0]),
        .lcd_data(w_left_chars_decoded0)
    );

    // lcd에 표시하기 시작하는 위치(view_start_addr)계산
    reg [ADDR_WIDTH-1:0] view_start_addr; 
    localparam LINE_SIZE = 1 << ONE_LINE_WIDTH; 
    always @(posedge lcd_slow_clk or posedge rst) begin
        if (rst) begin
            // 초기화
            view_start_addr <= 0;
        end
        else if (state == clear_display) begin
            // view_start_addr에 현재 위치의 이전 line의 첫번째 위치를 할당
            // 한 line의 칸 수가 2^4개이므로 하위 4비트를 0으로 마스킹
            view_start_addr <= (cur_addr - LINE_SIZE) & 10'b1111110000;
        end
    end

    always @ (posedge lcd_slow_clk or posedge rst) begin
        if (rst) counter <= 0;
        else begin
            case (state)
                delay:          if (counter == 70)  counter <= 0; else counter <= counter + 1;
                function_set:   if (counter == 30)  counter <= 0; else counter <= counter + 1;
                display_onoff:  if (counter == 30)  counter <= 0; else counter <= counter + 1;
                entry_mode:     if (counter == 30)  counter <= 0; else counter <= counter + 1;
                line1:          if (counter == 20)  counter <= 0; else counter <= counter + 1;
                line2:          if (counter == 20)  counter <= 0; else counter <= counter + 1;
                delay_t:        if (counter == 400) counter <= 0; else counter <= counter + 1;
                clear_display:  if (counter == 200) counter <= 0; else counter <= counter + 1;
                default:                            counter <= 0;
            endcase
        end
    end

    always @ (posedge lcd_slow_clk or posedge rst) begin
        if (rst) state <= delay;
        else begin
            case (state)
                delay:          if (counter == 70)  state <= function_set;
                function_set:   if (counter == 30)  state <= display_onoff;
                display_onoff:  if (counter == 30)  state <= entry_mode;
                entry_mode:     if (counter == 30)  state <= line1;
                line1:          if (counter == 20)  state <= line2;
                line2:          if (counter == 20)  state <= delay_t;
                delay_t:        if (counter == 400) state <= clear_display;
                clear_display:  if (counter == 200) state <= line1;
            endcase
        end
    end

    always @ (posedge lcd_slow_clk or posedge rst) begin
        if (rst) begin
            lcd_rs <= 1'b1;
            lcd_rw <= 1'b1;
            lcd_data <= 8'b0000_0000;
            sram_rd_addr <= 0;
        end
        else begin
            case (state)
                function_set: begin 
                    lcd_rs <= 1'b0; lcd_rw <= 1'b0; lcd_data <= 8'b0011_1100; 
                end
                display_onoff: begin 
                    lcd_rs <= 1'b0; lcd_rw <= 1'b0; lcd_data <= 8'b0000_1100; 
                end
                entry_mode: begin 
                    lcd_rs <= 1'b0; lcd_rw <= 1'b0; lcd_data <= 8'b0000_0110; 
                end
                delay_t: begin 
                    lcd_rs <= 1'b0; lcd_rw <= 1'b0; lcd_data <= 8'b0000_0010; 
                end
                clear_display: begin 
                    lcd_rs <= 1'b0; lcd_rw <= 1'b0; lcd_data <= 8'b0000_0001; 
                end

                // Line 1
                line1: begin
                    lcd_rw <= 1'b0; //LCD에 데이터를 쓸 것
                    if (counter == 0) begin
                        lcd_rs <= 1'b0;                      		// 명령 모드
                        lcd_data <= 8'b1000_0000;            		// DDRAM의 주소를 1행 1열로 설정
                        sram_rd_addr <= view_start_addr;     	// SRAM의 첫번째 점자 데이터 주소를 요청
                    end
                    else if (counter == 1) begin
                        lcd_rs <= 1'b1;                      		// 데이터 모드
                        sram_rd_addr <= view_start_addr + 1; 	// SRAM에 두 번째 데이터 주소 요청
                        lcd_data <= w_ascii_data;            		// SRAM에서 읽어온 첫번째 점자를 LCD로 출력
                    end
                    else if (counter <= 17) begin 
                        lcd_rs <= 1'b1;                      		// 데이터 모드
                        sram_rd_addr <= view_start_addr + counter; // 현재 위치보다 1칸 앞선 주소를 미리 요청
                        lcd_data <= w_ascii_data;            		// SRAM에서 읽어온 점자를 LCD로 출력
                    end
                    else begin
                         lcd_rs <= 1'b1; lcd_data <= 8'b0010_0000; //출력할 데이터가 없는 곳에는 공백 출력
                    end
                end

                // Line 2
                line2: begin
                    lcd_rw <= 1'b0;
                    if (counter == 0) begin
                        lcd_rs <= 1'b0;                           			// 명령 모드
                        lcd_data <= 8'b1100_0000;                 		// DDRAM의 주소를 2행 1열로 설정
                        sram_rd_addr <= view_start_addr + 16;     	// SRAM의 첫번째 점자 데이터 주소를 요청
                    end
                    else if (counter == 1) begin
                        lcd_rs <= 1'b1;                           			// 데이터 모드
                        sram_rd_addr <= view_start_addr + 16 + 1; 	// SRAM에 두 번째 데이터 주소 요청
                        lcd_data <= w_ascii_data;                 		// SRAM에서 읽어온 첫번째 점자를 LCD로 출력
                    end
                    else if (counter <= cur_addr[3:0]) begin      		// 데이터가 입력이 완료된 곳까지 lcd로 data를 출력
                        lcd_rs <= 1'b1;                           			// 데이터 모드
                        sram_rd_addr <= view_start_addr + 16 + counter; // 주소 갱신
                        lcd_data <= w_ascii_data;                 		// SRAM에서 읽어온 점자를 LCD로 출력
                    end
                    else if (counter <= 17) begin
                        lcd_rs <= 1'b1; // 데이터 모드
                        // 자동완성 가능한 단어 중 아직 입력되지 않는 점자를 lcd에 깜빡이며 표시
                        // autocomplete_able == 1 (자동완성 가능한 단어가 있는 경우)에만 lcd에 글자를 보여줌
                        // blink_on == 1일 때만 lcd에 글자를 보여줌 -> 점멸 효과
                        case (counter - cur_addr[3:0])
                            3'd1: lcd_data <= (autocomplete_able && blink_on) ? w_left_chars_decoded2 : 8'b0010_0000;
                            3'd2: lcd_data <= (autocomplete_able && blink_on) ? w_left_chars_decoded1 : 8'b0010_0000;
                            3'd3: lcd_data <= (autocomplete_able && blink_on) ? w_left_chars_decoded0 : 8'b0010_0000;
                            default: lcd_data <= 8'b0010_0000;
                        endcase
                    end
                    
                    else begin
                         lcd_rs <= 1'b1; lcd_data <= 8'b0010_0000; //공백 출력
                    end
                end

                default: begin 
                    lcd_rs <= 1'b1; lcd_rw <= 1'b1; lcd_data <= 8'b0000_0000; //공백 출력
                end
            endcase
        end
    end

    assign lcd_enb = lcd_slow_clk; 

endmodule