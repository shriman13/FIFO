`timescale 1ns/1ps
// Test the complete button/debounce/FIFO hierarchy with a short qualification time.
module tb_fifo_test;
    reg clk_100MHz=0;
    always #5 clk_100MHz=~clk_100MHz;
    reg reset=0,wr=0,rd=0;
    reg [2:0] sw=0;
    wire [2:0] data_out;
    wire full,empty;
    fifo_test #(.DEBOUNCE_BITS(3)) dut (
        .clk_100MHz(clk_100MHz),.reset(reset),.wr(wr),.rd(rd),
        .sw(sw),.data_out(data_out),.full(full),.empty(empty)
    );
    integer writes=0,reads=0,k;
    always @(posedge clk_100MHz) begin
        if (!reset) begin
            if (dut.write_tick && !full) writes=writes+1;
            if (dut.read_tick && !empty) reads=reads+1;
        end
    end
    task check;
        input condition;
        input [8*100-1:0] message;
        begin
            if(condition !== 1'b1) begin
                $display("TOP FAIL: %0s",message);$fatal(1,"FIFO TOP CHECK FAILED");
            end
        end
    endtask
    task settle;
        begin repeat(20) @(negedge clk_100MHz); end
    endtask
    task push;
        input [2:0] data;
        begin sw=data;wr=1;settle;wr=0;settle;end
    endtask
    task pop;
        input [2:0] expected;
        begin
            check(!empty,"unexpected empty before pop");
            check(data_out===expected,"top-level FIFO order mismatch");
            rd=1;settle;rd=0;settle;
        end
    endtask
    initial begin
        @(negedge clk_100MHz);reset=1;settle;reset=0;settle;
        // Pulses shorter than the 8-clock qualification must be rejected.
        sw=7;
        for(k=0;k<3;k=k+1) begin
            wr=1;repeat(2) @(negedge clk_100MHz);
            wr=0;repeat(3) @(negedge clk_100MHz);
        end
        settle;check(writes==0 && empty,"short contact bounce accepted");
        $display("PASS TOP: short bounce pulses are rejected");
        push(1);push(3);push(5);push(7);
        check(writes==4 && full,"four button presses did not fill FIFO");
        $display("PASS TOP: one operation per accepted button press");
        // One long press may produce exactly one write tick, not repeated writes.
        wr=1;repeat(80) @(negedge clk_100MHz);wr=0;settle;
        check(writes==4,"full FIFO accepted a write");
        pop(1);pop(3);pop(5);pop(7);
        check(reads==4 && empty,"drain flags/count mismatch");
        sw=2;wr=1;repeat(80) @(negedge clk_100MHz);
        check(writes==5 && dut.count==1,"held button generated multiple writes");
        wr=0;settle;pop(2);
        rd=1;settle;rd=0;settle;
        check(reads==5 && empty,"empty FIFO accepted a read");
        $display("ALL FIFO TOP TESTS PASSED: debounce, held buttons, full/empty blocking, and data order");
        $finish;
    end
    initial begin #100000;$fatal(1,"Top testbench watchdog timeout");end
endmodule
