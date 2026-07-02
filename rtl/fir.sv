module fir #(
    parameter N = 16, // 16, 32, 64 for low-pass filter
                      // 17, 33, 65 for high-pass filter
    parameter M = $clog2(N), 

    // FIFO parameter
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 4,
    parameter FIFO_LOG2_DEPT = $clog2(FIFO_DEPTH)
    )(
    input  logic                clk,
    input  logic                n_rst,

    // slave interface
    input  logic                s_valid,
    output logic                s_ready,
    input  logic signed [N-1:0] s_data,

    // master interface
    output logic                m_valid,
    input  logic                m_ready,
    output logic signed [N-1:0] m_data
);

//-------------------------------------
// ports with In/Out FIFO
//-------------------------------------
// FIFO slave interface
logic                w_s_valid;
logic                w_s_ready;
// assign               w_s_ready = (present_state == IDLE) ? 1'b1 : 1'b0;
logic signed [N-1:0] w_s_data;

// FIFO master interface
logic                w_m_valid;
// assign               w_m_valid = (present_state == DONE) ? 1'b1 : 1'b0;
logic                w_m_ready;
logic signed [N-1:0] w_m_data;

logic output_ready;

// handshake
logic i_hs;
assign i_hs = w_s_valid & w_s_ready;

logic o_hs;
assign o_hs = w_m_valid & w_m_ready;


// Samples
typedef logic signed [N-1:0] sample_array;
sample_array samples [0:N-1];

// Filter coefficients (16-tap low-pass filter)
const sample_array coefficients [0:N-1] =
'{30,136,457,1119,2116,3278,4317,4932,4932,4317,3278,2116,1119,457,136,30}; // multiplied by 2^15  

// Filter coefficients (32-tap low-pass filter) 
/* const sample_array coefficients [0:N-1] = 
'{-685868,-2333641,-4920182,-8682150,-12959082,-16002474,-15146752,-7353236,
9980676,38151597,76467085,121969759,169694795,213449944,246964578,265146778,265146778,246964578,213449944,169694795,
121969759,76467085,38151597,9980676,-7353236,-15146752,-16002474,-12959082,-8682150,-4920182,-2333641,685868}; */

// // Filter coefficients (64-tap low-pass filter)
/* const sample_array coefficients [0:N-1] = 
'{-64'd14586456119915848,-64'd4412070690462699,-64'd7394025546276164,-64'd10174167849513228,-64'd12190738240757988,-64'd12562478871635114,-64'd10256693521176334,
-64'd4397703587761053,64'd5347063590582193,64'd18403026615891304,64'd33061738681226824,64'd46494385106844704,64'd55067337187053752,64'd54958307175220352,64'd42998368219009688,
64'd17597776781487378,-64'd20431612609424680,-64'd67354651760872184,-64'd116457928450385984,-64'd158556889587513440,-64'd183061173861213056,-64'd179484114271164800,-64'd139182765415997744,
-64'd57046712811904280,64'd67166575326380792,64'd228117347420785888,64'd414970449012191104,64'd612337490776498432,64'd801984360557633152,64'd965078464149975552,
64'd1084648048665225728,64'd1147877443929967104,64'd1147877443929967104,64'd1084648048665225728,64'd965078464149975552,64'd801984360557633152,64'd612337490776498432,
64'd414970449012191104,64'd228117347420785888,64'd67166575326380792,-64'd57046712811904280,-64'd139182765415997744,-64'd179484114271164800,-64'd183061173861213056,
-64'd158556889587513440,-64'd116457928450385984,-64'd67354651760872184,-64'd20431612609424680,64'd17597776781487378,64'd42998368219009688,64'd54958307175220352,
64'd55067337187053752,64'd46494385106844704,64'd33061738681226824,64'd18403026615891304,64'd5347063590582193,-64'd4397703587761053,-64'd10256693521176334,
-64'd12562478871635114,-64'd12190738240757988,-64'd10174167849513228,-64'd7394025546276164,-64'd4412070690462699,-64'd1458456119915848}; */

// Filter coefficients (17-tap high-pass filter)
/* const sample_array coefficients [0:N-1] = 
'{0,-66,-264,-701,-1407,-2299,-3189,-3850,28658,-3850,-3189,-2299,-1407,-701,-264,-66,0}; */

// Filter coefficients (33-tap high-pass filter)
/* const sample_array coefficients [0:N-1] = 
'{0,24,61,117,187,249,269,200,0,-359,-880,-1534,-2257,-2964,-3560,-3957,28681,-3957,-3560,-2964,-2257,-1534,-880,
-359,0,200,269,249,187,117,61,24,0}; */ 

// Filter coefficients (65-tap high-pass filter)
/* const sample_array coefficients [0:N-1] = 
'{0,11,22,33,43,48,45,29,0,-43,-95,-148,-190,-206,-185,-116,0,156,332,499,622,663,587,369,0,-511,-1134,-1823,-2517,
-3149,-3656,-3983,28676,-3983,-3656,-3149,-2517,-1823,-1134,-511,0,369,587,663,622,499,332,156,0,-116,-185,-206,-190,
-148,-95,-43,0,29,45,48,43,33,22,11,0}; */

// State
typedef enum logic [2:0] {IDLE, LOAD, PROCESS, ARRANGE, DONE} state_type;
state_type present_state;
state_type next_state;

// pipeline register
logic signed [N-1:0] reg_sample [0:3];
logic signed [N-1:0] reg_coefficient [0:3];

// address counter
logic unsigned [M:0] address; 

// sum
logic signed [2*N-1:0] sum;
logic signed [2*N-1:0] reg_sum1;     // partial sum register
logic signed [2*N-1:0] reg_sum2;     // partial sum register
// logic signed [2*N-1:0] reg_sum3;  // partial sum register for high-pass

// control signals
logic reset_accumulator;
logic load;
logic count;
logic partial_sum; // partial sum en
logic final_sum;   // final sum en

// samples 
always_ff @(posedge clk) begin
    if(i_hs) begin
        for(int i = N-1; i >= 1; i--) begin
            samples[i] <= samples[i-1];
        end
    samples[0] <= w_s_data;
    end
end

// address
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst)
        address <= '0;
    else if(reset_accumulator)
        address <= '0;
    else if(count)
        address <= address + 4;
end

// Arrange state counter
logic arr_cnt;
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        arr_cnt <= 0;
    else if(present_state == ARRANGE)
        arr_cnt <= 1'b1;
    else 
        arr_cnt <= 1'b0;
end    

// --------------------------------------------------
// 1. Stage 1: Fetch
// --------------------------------------------------
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        reg_sample[0]      <= '0;
        reg_sample[1]      <= '0;
        reg_sample[2]      <= '0;
        reg_sample[3]      <= '0;
        reg_coefficient[0] <= '0;
        reg_coefficient[1] <= '0;
        reg_coefficient[2] <= '0;
        reg_coefficient[3] <= '0;
    end
    else if(count) begin
        reg_sample[0]      <= samples[address];
        reg_sample[1]      <= samples[address + 1];
        reg_sample[2]      <= samples[address + 2];
        reg_sample[3]      <= samples[address + 3];
        reg_coefficient[0] <= coefficients[address];
        reg_coefficient[1] <= coefficients[address + 1];
        reg_coefficient[2] <= coefficients[address + 2];
        reg_coefficient[3] <= coefficients[address + 3];
    end
end

// --------------------------------------------------
// 2. Stage 2: Partial sum
// --------------------------------------------------
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        reg_sum1 <= '0;
        reg_sum2 <= '0;
    end
    else if(reset_accumulator) begin
        reg_sum1 <= '0;
        reg_sum2 <= '0;
    end
    else if(partial_sum) begin
        reg_sum1 <= (reg_sample[0] * reg_coefficient[0]) + (reg_sample[1] * reg_coefficient[1]);
        reg_sum2 <= (reg_sample[2] * reg_coefficient[2]) + (reg_sample[3] * reg_coefficient[3]);
    end
end

// for high-pass filter
/* always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        reg_sum3 <= '0;
    else if(reset_accumulator)
        reg_sum3 <= '0;
    else if(address == N-4)
        reg_sum3 <= samples[N-1] * coefficients[N-1];
end */


// --------------------------------------------------
// 3. Stage 3: Final sum
// --------------------------------------------------
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        sum <= '0;
    else if(reset_accumulator) 
        sum <= '0;
    else if(final_sum)
        sum <= sum + reg_sum1 + reg_sum2; // for low-pass
         // sum <= sum + reg_sum1 + reg_sum2 + reg_sum3; for high-pass
end

logic signed [N-1:0] scaled_sum;
assign scaled_sum = $signed(sum) >>> (N-1);    // low-pass
// assign scaled_sum = $signed(sum) >>> (N-2); // for high-pass

// output
always_ff @(posedge clk) begin
    if(o_hs)
        w_m_data <= scaled_sum;
end  

// State transition
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst)
        present_state <= IDLE;
    else
        present_state <= next_state;
end

// Controller
always_comb begin
    reset_accumulator = 1'b0;
    load              = 1'b0;
    count             = 1'b0;
    partial_sum       = 1'b0;
    final_sum         = 1'b0;
    output_ready      = 1'b0;
    next_state        = present_state; // prevent latch

    case(present_state)
        IDLE: begin
            reset_accumulator = 1'b1;
            // w_s_ready = 1'b1;
            if(i_hs) next_state = PROCESS;
        end

        LOAD: begin
            load = 1'b1;
            reset_accumulator = 1'b1;
            next_state = PROCESS;
        end

        PROCESS: begin
            count  = 1'b1;
            if(address > 0) partial_sum = 1'b1; 
            if(address > 4) final_sum = 1'b1;
            if(address == N-4) begin        // for low-pass
            // if(address == N-5) begin    // for high-pass (17 taps)
            // if(address = N-1)  begin    // for high-pass (33, 65 taps)
                // count = 1'b0;
                next_state = ARRANGE;
            end
        end

        ARRANGE: begin // process remaining partial sum
            partial_sum = 1'b1;
            final_sum   = 1'b1;
            if(arr_cnt) begin
                partial_sum = 1'b0;
                final_sum   = 1'b1;
                next_state  = DONE;
            end
        end

        DONE: begin
            output_ready = 1'b1;
            // w_m_valid = 1;
            if(o_hs) next_state = IDLE;
            else next_state = DONE;
            end
        
        default: next_state = IDLE;
    endcase
end

// In/Out FIFO instantiation
sync_fifo #(
    .DATA_WIDTH     (N),
    .FIFO_DEPTH     (FIFO_DEPTH),
    .FIFO_LOG2_DEPT (FIFO_LOG2_DEPT)
) fifo_in (
    .clk            (clk),
    .n_rst          (n_rst),

    // slave interface
    .s_valid        (s_valid),
    .s_ready        (s_ready),
    .s_data         (s_data),

    // master interface
    .m_valid        (w_s_valid),
    .m_ready        (w_s_ready),
    .m_data         (w_s_data)
);

sync_fifo #(
    .DATA_WIDTH     (N),
    .FIFO_DEPTH     (FIFO_DEPTH),
    .FIFO_LOG2_DEPT (FIFO_LOG2_DEPT)
) fifo_out (
    .clk            (clk),
    .n_rst          (n_rst),

    // slave interface
    .s_valid        (w_m_valid),
    .s_ready        (w_m_ready),
    .s_data         (w_m_data),

    // master interface
    .m_valid        (m_valid),
    .m_ready        (m_ready),
    .m_data         (m_data)
);

assign w_s_ready = (present_state == IDLE) ? 1'b1 : 1'b0;
assign w_m_valid = (present_state == DONE) ? 1'b1 : 1'b0;

endmodule