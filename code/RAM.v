// =============================================================================
// Module Name: ram
// Description:
//     - 6비트 cell 2^10개 이용
//     - port a : read/write
//     - port b : read only
// =============================================================================

`timescale 1ns / 1ps
module ram #(
    parameter DATA_WIDTH = 6,     // sram의 한 cell의 bit수
    parameter ONE_LINE_WIDTH = 4, // 점자 2^ONE_LINE_WIDTH개를 한 개의 line으로 설정
    parameter ADDR_WIDTH = 10     // sram에 점자 2^ADDR_WIDTH개 저장 가능
)(
    input wire clk,
    input wire rst,

    // 실습 시간에 설계했던 sram의 구조 이용
    input wire we_a,
    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [DATA_WIDTH-1:0] data_in_a,
    output reg [DATA_WIDTH-1:0] data_out_a,

    input wire [ADDR_WIDTH-1:0] addr_b,
    output reg [DATA_WIDTH-1:0] data_out_b
);
    // 6bit cell들을 (1<<ADDR_WIDTH)개 배치 
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];
    
    integer i;
    initial begin 
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            ram[i] = {DATA_WIDTH{1'b0}}; //합성 시 초기값을 0으로 지정
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            // reset
            data_out_a <= {DATA_WIDTH{1'b0}};
        end else begin
            if (we_a) begin
                // we_a 신호가 1이면 a 포트에서 write
                ram[addr_a] <= data_in_a;
            end
            // 항상 addr_a에 해당하는 data를 a포트에서 출력
            data_out_a <= ram[addr_a];
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            // 초기화
            data_out_b <= {DATA_WIDTH{1'b0}};
        end else begin
            //항상 addr_b에 해당하는 data를 출력
            data_out_b <= ram[addr_b];
        end
    end
endmodule