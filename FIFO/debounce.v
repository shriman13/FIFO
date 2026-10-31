`timescale 1ns/1ps
// Synchronise an asynchronous button and qualify BOTH pressed and released levels.
// A new level must remain stable for 2**COUNTER_BITS clocks.
// At 100 MHz and COUNTER_BITS=22: 41.94304 ms, plus synchroniser latency.
module debounce #(
    parameter integer COUNTER_BITS = 22
)(
    input wire clk,
    input wire reset,
    input wire button,
    output reg level,
    output reg tick
);
    (* ASYNC_REG = "TRUE" *) reg sync_meta;
    (* ASYNC_REG = "TRUE" *) reg sync_button;
    reg [COUNTER_BITS-1:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sync_meta <= 0;
            sync_button <= 0;
        end else begin
            sync_meta <= button;
            sync_button <= sync_meta;
        end
    end
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            level <= 0;
            count <= 0;
            tick <= 0;
        end else begin
            tick <= 0;
            if (sync_button == level)
                count <= 0;
            else if (&count) begin
                level <= sync_button;
                count <= 0;
                if (sync_button)
                    tick <= 1;
            end else
                count <= count + 1'b1;
        end
    end
endmodule
