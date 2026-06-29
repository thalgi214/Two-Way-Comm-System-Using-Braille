//N 비트 입력을 받는 일반적인 decoder
`timescale 1ns / 1ps
module decoder_nbit #( 
    parameter N_BIT = 1
)(
    input en,
    input [N_BIT-1:0] I,
    output reg [(1<<N_BIT)-1:0] O
);
always @(*) begin
    O = en ? (1'b1<<I) : 0;
end
endmodule