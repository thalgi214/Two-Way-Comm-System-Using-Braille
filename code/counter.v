// =============================================================================
// Module Name: Counter_main
// Description:
//        - MAIN FSM에서 현재 동작에 해당하는 cmd 신호 counter에 전달
//        - counter에서 cmd 신호에 따라 addr을 갱신
// =============================================================================

`timescale 1ns / 1ps
module Counter_main #(
    parameter DATA_WIDTH = 6,     	// 6bit 점자 데이터
    parameter ONE_LINE_WIDTH = 4, 	//한 줄에 2^4개의 점자 데이터
    parameter ADDR_WIDTH = 10     	// 2^10개의 점자 저장 가능  
)(
    input clk, rst,
    input [2:0] cmd,                 		// 수행할 동작에 대한 명령
    output reg [ADDR_WIDTH-1:0] addr 	// cmd 값에 따라, 현재 수행중인 동작에 알맞게 main_fsm의 addr 갱신
);
    localparam CNT_IDLE  = 3'b000;          	//유지
    localparam CNT_SPACE   = 3'b001;        	//save (autowrite 포함)
    localparam CNT_BACKSPACE   = 3'b010;    	//backspace 
    localparam CNT_SEND = 3'b011;           	//send

    wire [ONE_LINE_WIDTH-1 : 0] line_cursor;     // 현재 line의 몇번째 칸을 입력 중인지에 대한 정보.
    assign line_cursor = addr[ONE_LINE_WIDTH-1:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 초기화
            addr <= 0;
        end
        else begin
            case (cmd)
                CNT_IDLE:  addr <= addr;         // 유지
                
                CNT_SPACE:   begin
                    addr <= addr + 1;            // save 동작 수행 시 addr += 1
                end
                CNT_BACKSPACE:   begin
                    addr <= addr - 1;            // backspace 동작 수행 시 addr -= 1
                end
                CNT_SEND: begin
                    // send 동작 수행했을 때 sram의 전체 용량을 넘지 않는 경우에만 다음 line의 첫번째 칸으로 위치 이동 
                    if (addr + ((1<<ONE_LINE_WIDTH) - line_cursor) < (1 << ADDR_WIDTH)) addr <= addr+((1<<ONE_LINE_WIDTH)-line_cursor);
                    else addr <= addr;           
                end
                default:   addr <= addr;
            endcase
        end
    end
endmodule