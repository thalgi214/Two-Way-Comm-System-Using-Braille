module full_adder (
    input x,
    input y,
    input c_in,
    output s,
    output c_out
);
    wire w1, w2, w3;

    half_adder HA1 (
        .x(x),
        .y(y),
        .s(w1),
        .c(w2)
    );

    half_adder HA2 (
        .x(c_in),
        .y(w1),
        .s(s),
        .c(w3)
    );

    assign c_out = w3 | w2;
endmodule
