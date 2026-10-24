
module fft_ram #(
    parameter N          = 32,                    // Memory depth (FFT points)
    parameter DATA_WIDTH = 16,                    // Bit width per real/imag part
    parameter ADDR_WIDTH = $clog2(N)             // Address bus width
)(
    input  wire                      clk,
    
    // Port A (Used for Sample A)
    input  wire                      we_a,
    input  wire [ADDR_WIDTH-1:0]     addr_a,
    input  wire [2*DATA_WIDTH-1:0]   din_a,
    output reg  [2*DATA_WIDTH-1:0]   dout_a,
    
    // Port B (Used for Sample B)
    input  wire                      we_b,
    input  wire [ADDR_WIDTH-1:0]     addr_b,
    input  wire [2*DATA_WIDTH-1:0]   din_b,
    output reg  [2*DATA_WIDTH-1:0]   dout_b
);

    // Shared memory grid
    reg [2*DATA_WIDTH-1:0] mem [0:N-1];

    // Port A operation
    always @(posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
        dout_a <= mem[addr_a];
    end

    // Port B operation
    always @(posedge clk) begin
        if (we_b) begin
            mem[addr_b] <= din_b;
        end
        dout_b <= mem[addr_b];
    end

endmodule