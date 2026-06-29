// =============================================================================
// Module Name: TOP_MODULE
// 
// Description:
//   - 최상위 모듈
//   - 버튼을 통해 발신자 정보 및 점자 신호를, 스위치를 통해 동작에 대한 명령을 입력받음
//   - led, text_lcd를 통해 입력받은 점자에 대한 정보를 출력
//   - led를 연결한 포트에 리니어 액추에이터를 연결함으로써 양방향 소통 구현 가능
//   - active high rst
// =============================================================================
`timescale 1ns / 1ps
module TOP_MODULE #(
    //sram
    parameter DATA_WIDTH          = 6, // sram의 한 cell의 bit수
    parameter ONE_LINE_WIDTH    = 4, // 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
    parameter ADDR_WIDTH         = 10, // sram에 점자 2^ADDR_WIDTH개 저장 가능

    //debouncer
    parameter FILTERINGTIME     = 20,

    //led fsm
    parameter DISP_TIME                = 26'd25000000,  //점멸 시 켜져있는 시간
    parameter BLINK_TIME              = 26'd25000000,  //점멸 시 꺼져있는 시간
    parameter DONE_HOLD_TIME     = 26'd50000000,  //led fsm 종료 후 점자 입력을 재개하는 과정

    //autocomplete
    parameter WORD_LEN          = 5, // autocomplete recommend 모듈에 내장할 단어의 길이
    parameter CHECK_LEN         = 2  // 자동완성 가능 여부 판정 시 검사할, 최근 입력된 점자의 개수
)(
    input wire clk,
    input wire rst,             
    
    // 입력 버튼
    input wire btn_A, btn_B, btn_C, btn_D, btn_E, btn_F, btn_G, btn_H,
    
    // 스위치
    input wire sw_A, sw_B, sw_C, sw_D, sw_E, sw_F, sw_G, sw_H,  //switch F, G, H는 사용하지 않음
    
    //led 
    output wire [5:0] braille_led, 
    output wire [1:0] user_led, 

    //text_lcd
    output wire lcd_enb,
    output wire lcd_rs, lcd_rw,
    output wire [7:0] lcd_data,

    //tft_lcd
    output wire tft_hsync,
    output wire tft_vsync,
    output wire tft_den,
    output wire tft_dclk,
    output wire tft_disp_en,
    output wire [7:0] tft_r,
    output wire [7:0] tft_g,
    output wire [7:0] tft_b
);
    wire w_user;                      //발신자(a : 0, b : 1) 에 대한 신호
    wire w_btn_user;                //발신자 toggle을 알리는 pulse 신호
    wire w_char_saved_pulse;     //led fsm 종료에 대한 pulse 신호
    wire [5:0] w_braille_data;      //입력된 점자에 대한 6비트 데이터

    wire w_switch_save;                         //save 동작을 알리는 pulse 신호
    wire w_switch_backspace;                 //backspace 동작을 알리는 pulse 신호
    wire w_switch_autocomplete;            //autocomplete 동작을 알리는 pulse 신호
    wire w_switch_send;                        //send 동작을 알리는 pulse 신호
    wire w_switch_autocomplete_mode;   //autocomplete_mode 진입을 알리는 flag 신호

    // SRAM
    wire w_we_main;
    wire [ADDR_WIDTH-1:0] w_addr_main;
    wire [5:0] w_data_in_main; 

    // 자동완성 관련 신호
    wire [DATA_WIDTH*CHECK_LEN-1:0] w_last_input;                   //최근 입력된 CHECK_LEN(프로젝트 내에서는 2)개의 점자에 대한 데이터
    wire w_autocomplete_able; 						 //자동완성 가능한 단어가 있는지에 대한 여부
    wire [DATA_WIDTH*(WORD_LEN-CHECK_LEN)-1:0] w_left_chars; //자동완성 가능한 단어 중 아직 실제로는 입력되지 않는 점자에 대한 데이터 

    // LED FSM 관련
    wire w_start_send; 			//send 동작 시 led fsm의 동작을 지시
    wire [7:0] w_msg_len; 		//send 된 line에 입력된 점자의 개수
    wire send_done; 			//led fsm 종료 신호. 해당 신호를 받고 main fsm에서의 입력 재개

    // 버튼 컨트롤러
    btn_top_controller #(
        .FILTERINGTIME(FILTERINGTIME)
    ) BTN_TOP_CTRL (
        .clk(clk),
        .rst(rst),
        .char_saved_pulse(w_char_saved_pulse), // 문자 저장 완료 신호 연결
        .btn_a_input(btn_A),
        .btn_b_input(btn_B),
        .btn_c_input(btn_C),
        .btn_d_input(btn_D),
        .btn_e_input(btn_E),
        .btn_f_input(btn_F),
        .btn_g_input(btn_G),
        .user(w_user),         		 //발신자(a : 0, b : 1) 에 대한 신호
        .btn_user(w_btn_user),		 //발신자 toggle을 알리는 pulse 신호
        .braille_data(w_braille_data) 	 //입력된 점자에 대한 6비트 데이터
    );

    // 스위치 컨트롤러
    switch_top_controller #(
        .FILTERINGTIME(FILTERINGTIME)
    ) SW_TOP_CTRL (
        .clk(clk),
        .rst(rst),
        
        .switch_a_input(sw_A),	        // Save
        .switch_b_input(sw_B), 		// Backspace
        .switch_c_input(sw_C), 		// Autocomplete 완료
        .switch_d_input(sw_D), 		// Send
        .switch_e_input(sw_E), 		// Autocomplete_Mode
        .switch_f_input(sw_F),
        .switch_g_input(sw_G),
        .switch_h_input(sw_H),

        // 스위치 출력 (A~D : 펄스 신호)
        .switch_a_output(w_switch_save),
        .switch_b_output(w_switch_backspace),
        .switch_c_output(w_switch_autocomplete), 
        .switch_d_output(w_switch_send),

        // 스위치 출력 (E~H : 플래그 신호)
        .switch_e_output(w_switch_autocomplete_mode),
        .switch_f_output(),
        .switch_g_output(),
        .switch_h_output()
    );

    // 사용자 LED
    supply1 p1;
    wire w_user_n = ~w_user;
    //발신자가 a(0)일 떄 10 출력
    //발신자가 b(1)일 떄 01 출력.
    //-> user 신호를 toggle하여 디코더에 연결
    decoder_nbit #(.N_BIT(1)) DECODER_LED (
        .en(p1),
        .I(w_user_n),
        .O(user_led)
    );
    
    //led 배치
    //  ____   ____   _______  _______  _______  _______   ______   _______ 
    //  | A |   | B |   | 점자 |  | 점자 |  | 점자 |  | 점자 |  | 점자 |  | 점자 |
    // ￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣
    //발신자가 
    // a 일 때 좌측 led on
    // b 일 때 우측 led on

    // 자동완성 Shift Register
    // 최근 입력된 2개의 데이터를 저장 및 출력
    word_shift_reg #(
        .DATA_WIDTH(DATA_WIDTH), // sram의 한 cell의 bit수
        .CHECK_LEN(CHECK_LEN) // 자동완성 가능 여부 판정 시 검사할, 최근 입력된 점자의 개수
    ) WORD_SHIFT_REG (
        .clk(clk),
        .rst(rst),
        .data_in(w_data_in_main), //main sram에 저장될 data를 그대로 복제

        .switch_save(w_char_saved_pulse), // 문자 저장 완료 신호 -> shift

        .switch_backspace(w_switch_backspace), // backspace 신호 -> word shift 초기화
        .switch_send(w_switch_send), //send 신호 -> word shift 초기화

        .last_input(w_last_input) //최근 입력된 점자 정보 출력
    );

    // Autocomplete Recommend
    // 최근 입력된 점자들을 기반으로 자동완성 가능한 단어 추천
    autocomplete_recommend #(
        .DATA_WIDTH(DATA_WIDTH),    			// sram의 한 cell의 bit수
        .CHECK_LEN(CHECK_LEN),         			// 자동완성 가능 여부 판정 시 검사할, 최근 입력된 점자의 개수
        .WORD_LEN(WORD_LEN)        			 // autocomplete recommend 모듈에 내장할 단어의 길이
    ) AUTO_RECOMMEND (
        .last_input(w_last_input),         			//최근 입력된 점자 정보 출력
        
        .autocomplete_able(w_autocomplete_able),  	//자동완성 가능한 단어가 있는지에 대한 여부
        .left_chars(w_left_chars) 				  	//자동완성 가능한 단어 중 아직 실제로는 입력되지 않는 점자에 대한 데이터 
    );

    // Main FSM
    main_fsm #(
        .DATA_WIDTH(DATA_WIDTH),            	// sram의 한 cell의 bit수
        .ONE_LINE_WIDTH(ONE_LINE_WIDTH),     // 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
        .ADDR_WIDTH(ADDR_WIDTH),                // sram에 점자 2^ADDR_WIDTH개 저장 가능
        .WORD_LEN(WORD_LEN),                	// autocomplete recommend 모듈에 내장할 단어의 길이
        .CHECK_LEN(CHECK_LEN)               	// 자동완성 가능 여부 판정 시 검사할, 최근 입력된 점자의 개수
    ) MAIN_FSM (
        .clk(clk),
        .rst(rst),

        .btn_user(w_btn_user), //발신자 toggle을 알리는 pulse 신호
        .user(w_user), //발신자(a : 0, b : 1) 에 대한 신호

        .braille_data(w_braille_data),			 //입력된 점자에 대한 6비트 데이터
        .switch_send(w_switch_send),			 //send -> 입력된 점자 sram에 저장 후 위치를 다음 line 첫번째 칸으로.
        .switch_save(w_switch_save), 			 //save -> 입력된 점자 sram에 저장 후 위치를 다음 칸으로.
        .switch_backspace(w_switch_backspace),    //backspace -> sram에 입력된 점자 하나 초기화 후 위치를 이전 칸으로.

        .switch_autocomplete_mode(w_switch_autocomplete_mode),	 //autocomplete_mode -> 자동완성 기능 활성화
        .switch_autocomplete(w_switch_autocomplete), 				//autocomplete -> 추천되는 단어로 자동완성 수락
        .autocomplete_able(w_autocomplete_able), 				//자동완성 가능한 단어가 있는지에 대한 여부
        .left_chars(w_left_chars),							        //자동완성 가능한 단어 중 아직 실제로는 입력되지 않는 점자에 대한 데이터 

        // SRAM
        .we(w_we_main),
        .addr(w_addr_main),
        .data_out(w_data_in_main),
        .char_saved_pulse(w_char_saved_pulse),// 문자 저장 완료 신호 연결

        .send_done(send_done), //led fsm 동작 완료 신호

        // LED FSM
        .start_send(w_start_send), 	//led fsm 동작 시작 신호
        .msg_len(w_msg_len)		 //send 된 line의 글자 수 -> 이를 기반으로 led fsm 종료 시점 결정됨
    );

    // MAIN_SRAM
    // led fsm으로 데이터 출력
    wire [ADDR_WIDTH-1:0] w_addr_led;
    wire [5:0] w_data_out_led;

    ram #(
        .DATA_WIDTH(DATA_WIDTH), 		// sram의 한 cell의 bit수
        .ONE_LINE_WIDTH(ONE_LINE_WIDTH), 	// 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
        .ADDR_WIDTH(ADDR_WIDTH) 		// sram에 점자 2^ADDR_WIDTH개 저장 가능
    ) MAIN_SRAM (
        .rst(rst),
        .clk(clk),
        .we_a(w_we_main),
        .addr_a(w_addr_main),
        .data_in_a(w_data_in_main),
        .data_out_a(),
        .addr_b(w_addr_led),
        .data_out_b(w_data_out_led)
    );

    // LED FSM
    led_fsm #(
        .DATA_WIDTH(DATA_WIDTH), 		// sram의 한 cell의 bit수
        .ONE_LINE_WIDTH(ONE_LINE_WIDTH), 	// 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
        .ADDR_WIDTH(ADDR_WIDTH), 		// sram에 점자 2^ADDR_WIDTH개 저장 가능
        .DISP_TIME(DISP_TIME), 				//점멸 시 켜져있는 시간
        .BLINK_TIME(BLINK_TIME), 			//점멸 시 꺼져있는 시간
        .DONE_HOLD_TIME(DONE_HOLD_TIME) 	//led fsm 종료 후 점자 입력을 재개하는 과정
    ) LED_FSM (
        .clk(clk),
        .rst(rst),
        .start_send(w_start_send), 		//led fsm 동작 시작 신호
        .msg_len(w_msg_len), 			//send 된 line에 입력된 점자의 개수
        .last_write_addr(w_addr_main), 	//send동작이 발생한 위치. 이 위치에 해당하는 line의 첫번째 칸의 위치를 계산해 led fsm에서 읽기 시작
        .rd_addr(w_addr_led),
        .rd_data(w_data_out_led),
        .led_out(braille_led), 			//led의 on/off 여부에 대한 신호
        .send_done(send_done) 		//led fsm 종료 신호.
    );

    // SUB SRAM
    // text lcd로 data 출력. main_sram에 저장되는 단어를 그대로 sub sram에 저장.
    wire [ADDR_WIDTH-1:0] w_subsram_textlcd_addr;
    wire [5:0] w_subsram_textlcd_data;

    ram #(
        .DATA_WIDTH(DATA_WIDTH), 		// sram의 한 cell의 bit수
        .ONE_LINE_WIDTH(ONE_LINE_WIDTH), 	// 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
        .ADDR_WIDTH(ADDR_WIDTH) 		// sram에 점자 2^ADDR_WIDTH개 저장 가능
    ) SUB_SRAM (
        .rst(rst),
        .clk(clk),
        .we_a(w_we_main),
        .addr_a(w_addr_main),
        .data_in_a(w_data_in_main),
        .data_out_a(),
        .addr_b(w_subsram_textlcd_addr),
        .data_out_b(w_subsram_textlcd_data)
    );

    // TEXT LCD
    text_lcd #(
        .ADDR_WIDTH(ADDR_WIDTH), 		// sram에 점자 2^ADDR_WIDTH개 저장 가능
        .DATA_WIDTH(DATA_WIDTH), 		// sram의 한 cell의 bit수
        .ONE_LINE_WIDTH(ONE_LINE_WIDTH) 	// 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
    ) TEXT_LCD (
        .clk(clk),
        .rst(rst),
        .cur_addr(w_addr_main),
        .sram_rd_addr(w_subsram_textlcd_addr), //sub sram에 저장된 단어 읽어들임
        .sram_rd_data(w_subsram_textlcd_data),
        .lcd_enb(lcd_enb),
        .lcd_rs(lcd_rs),
        .lcd_rw(lcd_rw),
        .lcd_data(lcd_data),
        .autocomplete_able(w_autocomplete_able), 	//자동완성 가능한 단어가 있는지에 대한 여부
        .left_chars(w_left_chars) 					//자동완성 가능한 단어 중 아직 실제로는 입력되지 않는 점자에 대한 데이터 
    );

    // TFT LCD
    // 카카오톡 로고. UI 요소.
    TFT_LCD_top TFT_MODULE (
        .clk(clk),
        .rst(rst),
        .R(tft_r),
        .G(tft_g),
        .B(tft_b),
        .hsync(tft_hsync),
        .vsync(tft_vsync),
        .den(tft_den),
        .dclk(tft_dclk),
        .disp_en(tft_disp_en)
    );

endmodule