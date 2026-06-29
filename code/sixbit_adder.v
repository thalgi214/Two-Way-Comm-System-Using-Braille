module sixbit_adder (
    input [5:0] A, //6bit operand A, B
    input [5:0] B,
    input c_in, // carry_in
    output [5:0] S, //6bit output S
    output c_out, // carry _out
    output v  // 오버플로우 출력
);
    wire [6:1] C; //c1~c4까지, c4는 c_out
    
    full_adder FA1 (
        .c_in(c_in),
        .x(A[0]),
        .y(B[0]),
        .s(S[0]),
        .c_out(C[1])
    );
    
    full_adder FA2 (
        .c_in(C[1]),
        .x(A[1]),
        .y(B[1]),
        .s(S[1]),
        .c_out(C[2])
    );
    
    full_adder FA3 (
        .c_in(C[2]),
        .x(A[2]),
        .y(B[2]),
        .s(S[2]),
        .c_out(C[3])
    );
    
    full_adder FA4 (
        .c_in(C[3]),
        .x(A[3]),
        .y(B[3]),
        .s(S[3]),
        .c_out(C[4])
    );
    
    full_adder FA5 (
        .c_in(C[4]),
        .x(A[4]),
        .y(B[4]),
        .s(S[4]),
        .c_out(C[5])
    );

    full_adder FA6 (
        .c_in(C[5]),
        .x(A[5]),
        .y(B[5]),
        .s(S[5]),
        .c_out(C[6])
    );
    assign c_out = C[6];     //최종 full adder의 carry_out을 전체 carry_out으로
    assign v = C[6] ^ C[5];  // 오버플로우 검출
endmodule
