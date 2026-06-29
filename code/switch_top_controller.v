// =============================================================================
// Module Name: switch_top_controller
// Description:
//   - 실질적으로 사용하는 5개의 스위치를 포함한 FPGA의 전체 dip switch 8개를 제어
//   - 입력 신호를 디바운싱
//   - 신호 a~d는 pulse, e는 flag 신호
// =============================================================================

`timescale 1ns / 1ps
module switch_top_controller #(
    parameter FILTERINGTIME = 20
)(
    input wire clk,
    input wire rst,

    //입력
    input wire switch_a_input,
    input wire switch_b_input,
    input wire switch_c_input,
    input wire switch_d_input,
    input wire switch_e_input,
    input wire switch_f_input, // 본 프로젝트에서는 사용 x
    input wire switch_g_input, // 본 프로젝트에서는 사용 x
    input wire switch_h_input, // 본 프로젝트에서는 사용 x

    // 출력
    output wire switch_a_output, // Pulse 신호
    output wire switch_b_output, // Pulse 신호
    output wire switch_c_output, // Pulse 신호
    output wire switch_d_output, // Pulse 신호
    
    output wire switch_e_output, // flag 신호
    output wire switch_f_output, // flag 신호
    output wire switch_g_output, // flag 신호
    output wire switch_h_output  // flag 신호
);

    // 입력 디바운싱
    wire [7:0] not_debounced_switches; //debounced 되지 않은 신호
    assign not_debounced_switches = {
        switch_h_input, switch_g_input, switch_f_input, switch_e_input,
        switch_d_input, switch_c_input, switch_b_input, switch_a_input
    };
    wire [7:0] debounced_switches; //debounced 된 신호

    genvar i;
    generate //각 switch 신호에 디바운서 연결
        for (i = 0; i < 8; i = i + 1) begin : gen
            debouncer #(
                .FILTERINGTIME(FILTERINGTIME)
            ) SWITCH_DEBOUNCER (
                .clk(clk), 
                .rst(rst), 
                .not_debounced_signal(not_debounced_switches[i]), 
                .debounced_signal(debounced_switches[i])
            );
        end
    endgenerate

    // switch 신호를 pulse 신호로 변환
    reg [7:0] prev_debounced_switches; //이전 스위치 신호
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prev_debounced_switches <= 8'b0;
        end else begin
            prev_debounced_switches <= debounced_switches;
        end
    end
    // 스위치 신호가 0에서 1이 되는 순간 switch_posedge=1
    wire [7:0] switch_posedge; assign switch_posedge = debounced_switches & ~prev_debounced_switches;

    // 출력
    // 스위치가 켜지는 순간만 1
    assign switch_a_output = switch_posedge[0];     // save 신호
    assign switch_b_output = switch_posedge[1];     // backspace 신호
    assign switch_c_output = switch_posedge[2];     // autocomplete 수락 신호
    assign switch_d_output = switch_posedge[3];     // send 신호
    
    // 스위치가 켜져 있는 동안 계속 1 유지
    assign switch_e_output = debounced_switches[4]; // autocomplete mode 전환 신호
    assign switch_f_output = debounced_switches[5]; // 본 프로젝트에서는 사용 x
    assign switch_g_output = debounced_switches[6]; // 본 프로젝트에서는 사용 x
    assign switch_h_output = debounced_switches[7]; // 본 프로젝트에서는 사용 x
endmodule