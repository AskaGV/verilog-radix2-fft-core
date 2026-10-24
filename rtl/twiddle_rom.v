`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.10.2026 15:39:22
// Design Name: 
// Module Name: twiddle_rom
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



// Parameterized Twiddle Factor Lookup ROM for N-point FFT.
// Reads packed 32-bit Q2.14 entries from twiddle_q14.hex:
// Bits [31:16]: Real Part (Cosine)
// Bits [15:0] : Imaginary Part (-Sine)


module twiddle_rom #(
    parameter N          = 32,                    // FFT Point Size
    parameter DATA_WIDTH = 16,                    // Q2.14 Word Width
    parameter ADDR_WIDTH = $clog2(N/2)            // Address bits (N=32 -> 4 bits for 16 entries)
)(
    input  wire                  clk,
    input  wire [ADDR_WIDTH-1:0] addr,            // Twiddle index k (0 to N/2 - 1)
    output reg  signed [DATA_WIDTH-1:0] w_real,   // Cosine component
    output reg  signed [DATA_WIDTH-1:0] w_imag    // Sine component
);

    // Array storing N/2 packed 32-bit words
    reg [2*DATA_WIDTH-1:0] rom [0:(N/2)-1];

    // Load pre-calculated fixed-point hex values during initialization
    initial begin
        $readmemh("twiddle_q14.hex", rom);
    end

    // Synchronous memory read (1 clock cycle latency)
    always @(posedge clk) begin
        w_real <= rom[addr][2*DATA_WIDTH-1 : DATA_WIDTH];
        w_imag <= rom[addr][DATA_WIDTH-1   : 0];
    end

endmodule
