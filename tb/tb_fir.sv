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
    start_time = 0;
    end_time = 0;
    latency = end_time - start_time;

    @(posedge clk);
    wait(s_valid == 1'b1);
    start_time = $realtime; 
    $display("[TIMING INFO] Calculation start time: %0t", start_time);

    @(posedge clk);
    wait(m_ready == 1'b1);
    end_time = $realtime;   
    $display("[TIMING INFO] Calculation end time: %0t", end_time);

    latency = end_time - start_time;
    $display("==================================================");
    $display("[PERFORMANCE REPORT] Total Latency: %0f ns", latency);
    $display("==================================================");
end

endmodule
