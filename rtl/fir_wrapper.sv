module fir_wrapper #(
    parameter DATA_WIDTH = 16  // 16, 32, 64 for low-pass
                               // 17, 33, 65 for high-pass
)(
    input  logic                         ACLK,
    input  logic                         ARESETn, 

    // slave interface
    input  logic                         S_AXIS_VALID,
    output logic                         S_AXIS_READY,
    input  logic signed [DATA_WIDTH-1:0] S_AXIS_DATA,

    // master interface
    output logic                         M_AXIS_VALID,
    input  logic                         M_AXIS_READY,
    output logic signed [DATA_WIDTH-1:0] M_AXIS_DATA
);

fir #(
    .N(DATA_WIDTH)
) f0 (
    .clk            (ACLK),
    .n_rst          (ARESETn),
    
    .s_valid        (S_AXIS_VALID),
    .s_ready        (S_AXIS_READY),
    .s_data         (S_AXIS_DATA),

    .m_valid        (M_AXIS_VALID),
    .m_ready        (M_AXIS_READY),
    .m_data         (M_AXIS_DATA)
);

endmodule