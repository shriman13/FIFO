`timescale 1ns/1ps
module tb_fifo;
    parameter integer DATA_SIZE = 3;
    parameter integer ADDR_SPACE_EXP = 2;
    localparam integer DEPTH = 2**ADDR_SPACE_EXP;
    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz
    reg reset = 0;
    reg write_to_fifo = 0;
    reg read_from_fifo = 0;
    reg [DATA_SIZE-1:0] write_data_in = 0;
    wire [DATA_SIZE-1:0] read_data_out;
    wire fifo_full, fifo_empty;
    wire [ADDR_SPACE_EXP:0] fifo_count;
    fifo #(.DATA_SIZE(DATA_SIZE), .ADDR_SPACE_EXP(ADDR_SPACE_EXP)) dut (
        .clk(clk), .reset(reset), .write_to_fifo(write_to_fifo),
        .read_from_fifo(read_from_fifo), .write_data_in(write_data_in),
        .read_data_out(read_data_out), .fifo_full(fifo_full),
        .fifo_empty(fifo_empty), .fifo_count(fifo_count)
    );

    // Reference model: shift the oldest word out, independently of DUT pointers.
    reg [DATA_SIZE-1:0] expected [0:DEPTH-1];
    integer expected_count = 0;
    integer cycles = 0, tests = 0, j, k;
    integer seed = 32'h51f01234;
    reg accepted_write, accepted_read;
    reg random_write, random_read;
    reg [DATA_SIZE-1:0] random_data;

    task check;
        input condition;
        input [8*160-1:0] message;
        begin
            if (condition !== 1'b1) begin
                $display("FAIL cycle=%0d time=%0t: %0s", cycles, $time, message);
                $fatal(1, "FIFO CHECK FAILED");
            end
        end
    endtask

    task apply;
        input wr_req;
        input rd_req;
        input [DATA_SIZE-1:0] data;
        begin
            @(negedge clk);
            write_to_fifo = wr_req;
            read_from_fifo = rd_req;
            write_data_in = data;
            #1;
            accepted_read  = rd_req && (expected_count > 0);
            accepted_write = wr_req && (expected_count < DEPTH);
            // With an asynchronous read port, compare the word BEFORE dequeue.
            if (accepted_read)
                check(read_data_out === expected[0], "dequeued data/order mismatch");
            if (accepted_read) begin
                for (j = 0; j < expected_count-1; j = j+1)
                    expected[j] = expected[j+1];
                expected_count = expected_count-1;
            end
            if (accepted_write) begin
                expected[expected_count] = data;
                expected_count = expected_count+1;
            end
            @(posedge clk);
            #1; // allow nonblocking updates to settle
            cycles = cycles+1;
            check(fifo_count === expected_count, "occupancy mismatch");
            check(fifo_empty === (expected_count == 0), "empty flag mismatch");
            check(fifo_full === (expected_count == DEPTH), "full flag mismatch");
            if (expected_count > 0)
                check(read_data_out === expected[0], "head word mismatch");
        end
    endtask

    task clear_fifo;
        begin
            @(negedge clk);
            reset = 1;
            write_to_fifo = 0;
            read_from_fifo = 0;
            expected_count = 0;
            #1;
            check(fifo_empty === 1'b1, "reset did not assert empty");
            check(fifo_full === 1'b0, "reset did not clear full");
            check(fifo_count === 0, "reset did not clear count");
            repeat (2) @(negedge clk);
            reset = 0;
        end
    endtask

    task passed;
        input [8*100-1:0] name;
        begin
            tests = tests+1;
            $display("PASS %0d: %0s", tests, name);
        end
    endtask

    initial begin
        // VCD is optional; Vivado uses its own waveform database by default.
        if ($test$plusargs("VCD")) begin
            $dumpfile("fifo.vcd");
            $dumpvars(0, tb_fifo);
        end
        clear_fifo;
        passed("reset establishes empty FIFO");
        apply(0,1,0); apply(0,1,0);
        passed("reads while empty are blocked");
        apply(1,0,1); apply(1,0,3);
        if (DEPTH == 4) begin
            apply(1,0,5); apply(1,0,7);
        end else begin
            for (k=2; k<DEPTH; k=k+1) apply(1,0,k);
        end
        check(fifo_full === 1'b1, "FIFO not full after DEPTH writes");
        passed("fill to capacity (4-word version writes 1,3,5,7)");
        apply(1,0,2); apply(1,0,4);
        passed("writes while full are blocked without overwriting queued words");
        while (expected_count > 0) apply(0,1,0);
        passed("drain preserves FIFO order and asserts empty");
        clear_fifo;
        apply(1,1,6); // empty: enqueue only
        check(expected_count == 1, "empty simultaneous policy");
        apply(1,1,2); // one word: dequeue old, enqueue new
        check(expected_count == 1, "intermediate simultaneous policy");
        passed("simultaneous requests at empty and intermediate occupancy");
        while (expected_count < DEPTH) apply(1,0,expected_count);
        apply(1,1,7); // full: dequeue only; incoming 7 is rejected
        check(expected_count == DEPTH-1, "full simultaneous policy");
        while (expected_count > 0) apply(0,1,0);
        passed("simultaneous requests while full accept the read only");
        for (k=0; k<3*DEPTH; k=k+1) begin
            apply(1,0,k);
            apply(0,1,0);
        end
        passed("multiple read and write pointer wrap-arounds");
        apply(1,0,3); apply(1,0,5);
        clear_fifo;
        apply(1,0,7); apply(0,1,0);
        passed("reset with stored data discards the old queue");
        // Reset must also suppress a write request held high.
        @(negedge clk); reset=1; write_to_fifo=1; write_data_in=3;
        repeat (2) @(negedge clk);
        write_to_fifo=0; reset=0; expected_count=0;
        apply(0,1,0); apply(1,0,2); apply(0,1,0);
        passed("reset takes priority over requests");
        for (k=0; k<1000; k=k+1) begin
            random_write = $random(seed);
            random_read = $random(seed);
            random_data = $random(seed);
            apply(random_write,random_read,random_data);
        end
        while (expected_count > 0) apply(0,1,0);
        passed("1000 deterministic pseudorandom request cycles with scoreboard");
        apply(0,0,0);
        $display("ALL FIFO TESTS PASSED: %0d groups, %0d checked cycles; width=%0d depth=%0d", tests,cycles,DATA_SIZE,DEPTH);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1,"Testbench watchdog timeout");
    end
endmodule
