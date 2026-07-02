module sync_fifo #(
    parameter DATA_WIDTH = 16,
    parameter FIFO_DEPTH = 4,
    parameter FIFO_LOG2_DEPT = $clog2(FIFO_DEPTH) // 2
)(
    input  logic                         clk,
    input  logic                         n_rst,

    // slave interface
    input  logic                         s_valid,
    output logic                         s_ready,
    input  logic signed [DATA_WIDTH-1:0] s_data,

    // master interface
    output logic                         m_valid,
    input  logic                         m_ready,
    output logic signed [DATA_WIDTH-1:0] m_data
);

// state
logic full;
logic empty;

// handshake
logic i_hs;
assign i_hs = s_valid & s_ready;
logic o_hs;
assign o_hs = m_valid & m_ready;

// pointer
logic [FIFO_LOG2_DEPT-1:0] wptr, wptr_next;
logic                      wptr_round, wptr_round_next;
logic [FIFO_LOG2_DEPT-1:0] rptr, rptr_next;
logic                      rptr_round, rptr_round_next;

// buffer
logic signed [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];

// write
integer i;
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        wptr       <= '0;
        wptr_round <= 1'b0;
        for(i = 0; i < FIFO_DEPTH; i = i + 1) // reset buffer
            mem[i] <= '0;
    end
    else if(i_hs) begin
        mem[wptr]  <= s_data;
        wptr       <= wptr_next;
        wptr_round <= wptr_round_next;
    end
end

always_comb begin
    if(wptr == (FIFO_DEPTH-1)) begin
        wptr_next       = '0;
        wptr_round_next = ~wptr_round;
    end
    else begin
        wptr_next       = wptr + 1'b1;
        wptr_round_next = wptr_round;
    end
end

// read
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        rptr       <= '0;
        rptr_round <= 1'b0;
    end
    else if(o_hs) begin
        rptr       <= rptr_next;
        rptr_round <= rptr_round_next;
    end
end

always_comb begin
    if(rptr == (FIFO_DEPTH-1)) begin
        rptr_next       = '0;
        rptr_round_next = ~rptr_round;
    end
    else begin
        rptr_next       = rptr + 1'b1;
        rptr_round_next = rptr_round;
    end
end

// 🛠️ 수정 완료된 Read Output 레지스터 구조
always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
        m_data <= '0;
    end
    else if(o_hs) begin
        m_data <= mem[rptr]; 
    end
end

assign full  = ((wptr == rptr) && (wptr_round != rptr_round)) ? 1'b1 : 1'b0;
assign empty = ((wptr == rptr) && (wptr_round == rptr_round)) ? 1'b1 : 1'b0;

assign s_ready = ~full;
assign m_valid = ~empty;

endmodule