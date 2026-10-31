`timescale 1ns/1ps
// Single-clock FIFO with an asynchronous (first-word fall-through) read port.
// Parameters require DATA_SIZE >= 1 and ADDR_SPACE_EXP >= 1.
module fifo #(
    parameter integer DATA_SIZE = 8,
    parameter integer ADDR_SPACE_EXP = 4
)(
    input  wire clk,
    input  wire reset,
    input  wire write_to_fifo,
    input  wire read_from_fifo,
    input  wire [DATA_SIZE-1:0] write_data_in,
    output wire [DATA_SIZE-1:0] read_data_out,
    output wire fifo_full,
    output wire fifo_empty,
    output reg  [ADDR_SPACE_EXP:0] fifo_count
);
    localparam integer DEPTH = 2**ADDR_SPACE_EXP;
    localparam [ADDR_SPACE_EXP:0] DEPTH_COUNT = DEPTH;
    reg [DATA_SIZE-1:0] memory [0:DEPTH-1];
    reg [ADDR_SPACE_EXP-1:0] current_write_addr;
    reg [ADDR_SPACE_EXP-1:0] current_read_addr;

    assign fifo_full  = (fifo_count == DEPTH_COUNT);
    assign fifo_empty = (fifo_count == 0);
    // Acceptance uses the occupancy BEFORE the active edge.
    // At full + both requests: read only. At empty + both: write only.
    wire write_enabled = write_to_fifo && !fifo_full;
    wire read_enabled  = read_from_fifo && !fifo_empty;
    // The head word is valid only while fifo_empty == 0. On an accepted read,
    // the consumer samples this word at the rising edge, BEFORE the pointer moves.
    assign read_data_out = memory[current_read_addr];

    // Memory need not be reset: resetting occupancy invalidates all old words.
    // Reset also prevents an accidental write while the FIFO is being cleared.
    always @(posedge clk) begin
        if (!reset && write_enabled)
            memory[current_write_addr] <= write_data_in;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_write_addr <= 0;
            current_read_addr <= 0;
            fifo_count <= 0;
        end else begin
            if (write_enabled)
                current_write_addr <= current_write_addr + 1'b1;
            if (read_enabled)
                current_read_addr <= current_read_addr + 1'b1;
            case ({write_enabled, read_enabled})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end
endmodule
