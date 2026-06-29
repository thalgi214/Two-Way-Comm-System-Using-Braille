// =============================================================================
// Module Name: debouncer
// Description:
//   - FPGA의 입력 신호의 바운싱 현상을 필터링
//   - 2FF-synchronizer 구조를 이용, 입력 신호를 2개의 reg에 걸쳐 입력받음
// =============================================================================

`timescale 1ns / 1ps
module debouncer(
   input   wire clk, 
   input   wire rst,
   input   wire not_debounced_signal, // 바운싱 가능성 있는 신호
   output wire debounced_signal      // 바운싱이 제거된 신호
);

parameter FILTERINGTIME = 20;  

reg input_signal_reg;                 		 // 입력된 신호, metastable 상태일 가능성 존재
reg input_signal_synchronized_reg;    	 // 2FF Synchronizer 구조 -> 입력된 신호를 한 클럭 대기한 뒤 받음 -> metastable 상태 없앰
reg cur_signal_reg;                    		// input_signal_synchronized_reg의 가장 최신 값
reg prev_signal_reg;                   		// input_signal_synchronized_reg의 한 클럭 이전의 값
reg debounced_signal_reg;              	// 디바운싱된 신호
reg [FILTERINGTIME : 0] counter;            // Counter
wire [FILTERINGTIME : 0] next_counter; assign next_counter = (counter [FILTERINGTIME])? counter : (counter + 1); // 다음 클럭의 카운터. 한계에 다다르면 더이상 증가시키지 않음
assign debounced_signal = debounced_signal_reg ;

always @(posedge clk) begin
   if (rst) begin
      // 초기화
      input_signal_reg <= 0;
      input_signal_synchronized_reg <= 0;
      
   end
   else begin
      input_signal_reg <= not_debounced_signal; // 입력된 신호
      input_signal_synchronized_reg <= input_signal_reg; // metastable이 제거된 입력 신호
   end
end

always @(posedge clk) begin
   if (rst) begin
      //초기화
      cur_signal_reg <= 0; 
      prev_signal_reg <= 0;
      debounced_signal_reg <= 0;
      counter <=  1;

   end
   else begin
      cur_signal_reg <= input_signal_synchronized_reg; // cur_signal_reg에 현재 신호 할당
      prev_signal_reg <= cur_signal_reg; // prev_signal_reg에 한 클럭 이전 신호 할당

      counter <= (prev_signal_reg == cur_signal_reg) ? next_counter : 1 ; // 이전 신호와 현재 신호가 같으면 counter를 1 늘리고, 다르면 1로 리셋
      if (counter [FILTERINGTIME]) begin
         // 지정된 시간 간격동안 현재 신호와 이전 신호가 같다면 
         // 바운싱이 종료된 것으로 판단
         // -> 신호를 debounced_signal_reg에 할당
         debounced_signal_reg <= prev_signal_reg ; 
      end
   end
end
endmodule