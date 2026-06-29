// =============================================================================
// Module Name: led_fsm
// Description:
//     - 현재 line에 입력된 모든 글자에 대한 점자 정보 순차 출력
//     - led_out 신호가 실제 led와 연결
//     - main fsm의 start_send를 받아 활성화
//     - 종료시 main fsm에 send_done 신호 전달
// =============================================================================

`timescale 1ns / 1ps
module led_fsm #(
        //sram
        parameter DATA_WIDTH        	= 6, // sram의 한 cell의 bit수
        parameter ONE_LINE_WIDTH    	= 4, // 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
        parameter ADDR_WIDTH        	= 10, // sram에 점자 2^ADDR_WIDTH개 저장 가능

        parameter DISP_TIME         		= 26'd25000000,  //점멸 시 켜져있는 시간
        parameter BLINK_TIME        		= 26'd25000000,  //점멸 시 꺼져있는 시간
        parameter DONE_HOLD_TIME    	= 26'd50000000  //led fsm 종료 후 점자 입력을 재개하는 과정
    )(
    input wire clk,
    input wire rst,
    
    // main fsm
    input wire start_send,       		// led fsm 동작 개시 신호      
    input wire [7:0] msg_len,    	// led fms에 현재 line에 입력된 점자 수 제공 
    output reg send_done,         	// led fsm 동작 종료  
    
    input wire [ADDR_WIDTH-1:0] last_write_addr, //send가 눌린 시점의 addr, led fsm이 sram의 데이터를 읽어들이는 시작 지점 계산 위함
    
    // sram
    output wire [ADDR_WIDTH-1:0] rd_addr, 
    input wire [5:0] rd_data,   
    
    // 실제 led에 표시할 신호
    output reg [5:0] led_out
);
    localparam S_IDLE       	= 4'd0; // 출력 시작 신호 대기, LED OFF 유지
    localparam S_WAIT       	= 4'd2; // MAIN FSM에서 신호를 받아 LED FSM 활성화
    localparam S_OUTPUT     	= 4'd3; // SRAM에 저장된 현재 인덱스의 6비트 점자 패턴을 LED ON
    localparam S_BLINK      	= 4'd4; // LED OFF -> 점멸 효과
    localparam S_NEXT       	= 4'd5; // 다음 인덱스로 이동, 표시할 점자가 남았는지 확인
    localparam S_DONE_HOLD  = 4'd6; // 완료 신호 MAIN FSM에 전달한 후 종료

    reg [3:0] state, next_state;
    reg [7:0] cnt;          
    reg [25:0] timer; //타이머, 해당 동작을 얼마나 지속할지 결정
    
    // sram에서 정보를 읽어들일 line의 첫번째 칸
    wire [ADDR_WIDTH-1:0] start_ptr; assign start_ptr = ((last_write_addr >> ONE_LINE_WIDTH) << ONE_LINE_WIDTH)-(1<<ONE_LINE_WIDTH);
    assign rd_addr = start_ptr + cnt+2; // line 헤더의 발신자 정보, ":" 를 고려, led fsm이 sram의 데이터를 읽어오는 실질적인 시작 지점

    always @(posedge clk or posedge rst) begin
        if (rst) state <= S_IDLE;
        else     state <= next_state;
    end

    reg [7:0] reg_len; //send 동작 시점의 msg_len을 저장.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 초기화
            cnt <= 0;
            reg_len <= 0;
            timer <= 0;
            led_out <= 6'b0;
            send_done <= 0;
        end else begin
            if (state != next_state) begin
                timer <= 0; // 상태가 바뀌는 순간 무조건 리셋
            end else begin
                // S_OUTPUT, S_BLINK, S_DONE_HOLD 상태가 유지될 때만 타이머 증가
                if (state == S_OUTPUT || state == S_BLINK || state == S_DONE_HOLD)
                    timer <= timer + 1;
                else
                    timer <= 0; // 그 외 상태에서는 0 유지
            end

            case (state)
                S_IDLE: begin // 대기 상태,
                    cnt <= 0; 
                    led_out <= 6'b0;
                    send_done <= 1'b0; 
                    if (start_send) reg_len <= msg_len; //msg_len 캡쳐
                end
                S_OUTPUT: led_out <= rd_data;   	// 현재 addr의 sram data를 led로 출력
                S_BLINK: led_out <= 6'b0;       	// led 잠시 off -> 점멸 효과
                S_NEXT: cnt <= cnt + 1;         	// cnt 증가
                S_DONE_HOLD: send_done <= 1'b1; // led fsm 종료 신호 main fsm에 전달
                default: ;
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)

            // S_IDLE
            //   ↓
            // S_WAIT   ← ← ← ←
            //   ↓              	↑
            // S_OUTPUT          ↑
            //   ↓              	↑
            // S_BLINK           	↑
            //   ↓              	↑
            // S_NEXT  → 아직 표시해야 할 점자 남았으면
            //   ↓
            // 표시할 점자 다 표시했으면
            //   ↓
            // S_DONE_HOLD 
            //   ↓
            // S_IDLE

            S_IDLE:      if (start_send && msg_len > 0) next_state = S_WAIT; 	// main fsm으로부터 시작 신호를 받았고 출력할 메시지가 있다면 fsm 활성화
            S_WAIT:      next_state = S_OUTPUT;                              		// sram의 데이터를 읽어올 때까지 대기
            S_OUTPUT:    if (timer >= DISP_TIME) next_state = S_BLINK;       	// DISP_TIME 동안 led on
            S_BLINK:     if (timer >= BLINK_TIME) next_state = S_NEXT;       	// BLINK_TIME동안 led off
            S_NEXT: begin                                                    			// 표시할 메시지가 남았다면 S_WAIT로 복귀
                if (cnt + 1 < reg_len)                                       			// 표시할 메시지가 남지 않았다면 S_DONE_HOLD
                    next_state = S_WAIT;      
                else           
                    next_state = S_DONE_HOLD; 
            end

            S_DONE_HOLD: begin                                               // DONE_HOLD_TIME 동안 대기 후 S_IDLE로 복귀
                if (timer >= DONE_HOLD_TIME) 
                    next_state = S_IDLE;
                else 
                    next_state = S_DONE_HOLD;
            end
            
            default: next_state = S_IDLE;
        endcase
    end
endmodule