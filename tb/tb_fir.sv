`timescale 1ns/100ps

module tb_fir;

parameter TB_N = 16; // 16, 32, 64 for low-pass
                     // 17, 33, 65 for high-pass

timeunit 1ns;
timeprecision 100ps;

logic                   clk;
logic                   n_rst;
logic                   s_valid; // input
logic                   s_ready;
logic signed [TB_N-1:0] s_data; // input
logic                   m_valid;
logic                   m_ready; // input
assign m_ready = 1'b1;
logic signed [TB_N-1:0] m_data;

real start_time;
real end_time;
real latency;

fir #(.N(TB_N)) m0 (
    .clk        (clk),
    .n_rst      (n_rst),
    .s_valid    (s_valid),
    .s_ready    (s_ready),
    .s_data     (s_data),
    .m_valid    (m_valid),
    .m_ready    (m_ready),
    .m_data     (m_data)
    );

// clock
initial begin
    clk = 1'b0;
    forever #500ns clk = ~clk; // period: 1us
end

// reset
initial begin
    n_rst = 1'b1;
    #10ns  n_rst = 1'b0; 
    #100ns n_rst = 1'b1; 
end

/* 
현재 DUE 는 sequential FIR Filter. 그래서 64비트를 사용하면 16비트를 사용하는 것보다 연산하는데 더 오래 걸림.
그래서 이를 고려하여 비트마다 sampling 되는 시점을 다르게 함.
16비트면 64 clock 마다, 32비트면 128 clock 마다, 64비트면 256 clock 마다 sampling
즉, input_ready 를 특정 clock 마다 trigger
*/
int sampling_clock_cycles;
assign sampling_clock_cycles = TB_N * 4; 

always begin
    s_valid = 1'b0;
    wait(n_rst == 1'b1);
    
    forever begin
        repeat(sampling_clock_cycles - 1) @(posedge clk);
        // s_valid = $urandom_range(0, 1);
        s_valid = 1'b1; 
        @(posedge clk);
        s_valid = 1'b0; 
        // s_valid = $urandom_range(0, 1);
    end
end 

initial begin
    s_data = '0;
    wait(n_rst == 1'b1);
    repeat(10) @(posedge clk); 
    
    forever begin
        s_data = -10000;
        repeat(8) begin 
            repeat(sampling_clock_cycles) @(posedge clk);
        end
        
        s_data = 10000;
        repeat(8) begin
            repeat(sampling_clock_cycles) @(posedge clk);
        end
    end
end

initial begin
    // 초기화
    start_time = 0;
    end_time = 0;
    latency = end_time - start_time;
    // 1. input_ready가 처음으로 켜지는(연산 시작) 시점 포착
    // (만약 최초 입력의 rising edge를 잡고 싶다면 @(posedge tb_fir.in)을 쓰셔도 됩니다)
    @(posedge clk);
    wait(s_valid == 1'b1);
    start_time = $realtime; // 현재 시간을 real 타입으로 저장 (단위: ns 또는 ps)
    $display("[TIMING INFO] 연산 시작 시간: %0t", start_time);

    // 2. 그 직후 output_ready가 처음으로 툭 켜지는(연산 완료) 시점 대기
    @(posedge clk);
    wait(m_ready == 1'b1);
    end_time = $realtime;   // 완료 시간 저장
    $display("[TIMING INFO] 연산 완료 시간: %0t", end_time);

    // 3. 차이 계산 및 출력
    latency = end_time - start_time;
    $display("==================================================");
    $display("[PERFORMANCE REPORT] 총 연산 지연 시간(Latency): %0f ns", latency);
    $display("==================================================");
end

endmodule