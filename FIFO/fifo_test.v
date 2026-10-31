`timescale 1ns/1ps
// Synthesis top matching the report's 100 MHz / 3-bit / 4-word configuration.
// DEBOUNCE_BITS=22 is the normal value; small values are for simulation only.
module fifo_test #(
    parameter integer DEBOUNCE_BITS = 22
)(
    input wire clk_100MHz,
    input wire reset,
    input wire wr,
    input wire rd,
    input wire [2:0] sw,
    output wire [2:0] data_out,
    output wire full,
    output wire empty
);
    wire write_tick, read_tick;
    wire write_level, read_level;
    wire [2:0] count;
    debounce #(.COUNTER_BITS(DEBOUNCE_BITS)) write_button (
        .clk(clk_100MHz), .reset(reset), .button(wr),
        .level(write_level), .tick(write_tick)
    );
    debounce #(.COUNTER_BITS(DEBOUNCE_BITS)) read_button (
        .clk(clk_100MHz), .reset(reset), .button(rd),
        .level(read_level), .tick(read_tick)
    );
    fifo #(.DATA_SIZE(3), .ADDR_SPACE_EXP(2)) fifo_inst (
        .clk(clk_100MHz), .reset(reset),
        .write_to_fifo(write_tick), .read_from_fifo(read_tick),
        .write_data_in(sw), .read_data_out(data_out),
        .fifo_full(full), .fifo_empty(empty), .fifo_count(count)
    );
endmodule
