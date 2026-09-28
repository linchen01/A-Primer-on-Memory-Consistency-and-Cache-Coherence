// Testbench for Synchronous FIFO
`timescale 1ns/1ps

module sync_fifo_tb;

    parameter int WIDTH = 8;
    parameter int DEPTH = 8;

    logic                 clk;
    logic                 rst_n;

    // Write port
    logic                 wr_en;
    logic [WIDTH-1:0]     wr_data;
    logic                 full;

    // Read port
    logic                 rd_en;
    logic [WIDTH-1:0]     rd_data;
    logic                 empty;

    // Status
    logic [$clog2(DEPTH):0] count;

    // Test counter
    int test_count = 0;
    int error_count = 0;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT instantiation
    sync_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty),
        .count(count)
    );

    initial begin
        $dumpfile("sync_fifo.vcd");
        $dumpvars(0, sync_fifo_tb);
    end

    task test_reset();
        $display("TEST: Reset functionality");
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        #10;

        rst_n = 1;
        #10;

        if (empty !== 1'b1) begin
            $display("ERROR: FIFO should be empty after reset");
            error_count++;
        end
        if (full !== 1'b0) begin
            $display("ERROR: FIFO should not be full after reset");
            error_count++;
        end
        if (count !== 0) begin
            $display("ERROR: Count should be 0 after reset");
            error_count++;
        end

        $display("PASS: Reset test completed\n");
        test_count++;
    endtask

    task test_write_full();
        logic [WIDTH-1:0] data;

        $display("TEST: Write until full");

        // Write 8 items
        for (int i = 0; i < 8; i++) begin
            data = i;
            wr_data = data;
            wr_en = 1;
            @(posedge clk);

            if (i < 7) begin
                if (full === 1'b1) begin
                    $display("ERROR: FIFO marked as full before depth reached (iteration %0d)", i);
                    error_count++;
                end
            end
        end

        wr_en = 0;
        @(posedge clk);

        if (full !== 1'b1) begin
            $display("ERROR: FIFO should be full after writing 8 items");
            error_count++;
        end

        if (count !== DEPTH) begin
            $display("ERROR: Count should be %0d, got %0d", DEPTH, count);
            error_count++;
        end

        $display("PASS: Write until full test completed\n");
        test_count++;
    endtask

    task test_read_empty();
        logic [WIDTH-1:0] data;

        $display("TEST: Read until empty");

        // Read 8 items
        for (int i = 0; i < 8; i++) begin
            rd_en = 1;
            @(posedge clk);

            if (rd_data !== i) begin
                $display("ERROR: Read data mismatch at iteration %0d: expected %0d, got %0d", i, i, rd_data);
                error_count++;
            end

            if (i < 7) begin
                if (empty === 1'b1) begin
                    $display("ERROR: FIFO marked as empty before all items read (iteration %0d)", i);
                    error_count++;
                end
            end
        end

        rd_en = 0;
        @(posedge clk);

        if (empty !== 1'b1) begin
            $display("ERROR: FIFO should be empty after reading all items");
            error_count++;
        end

        $display("PASS: Read until empty test completed\n");
        test_count++;
    endtask

    task test_simultaneous_rw();
        logic [WIDTH-1:0] wr_val = 16'hABCD;

        $display("TEST: Simultaneous read/write");

        // First fill the FIFO partially
        for (int i = 0; i < 4; i++) begin
            wr_data = 8'hA0 + i;
            wr_en = 1;
            rd_en = 0;
            @(posedge clk);
        end

        wr_en = 0;
        rd_en = 0;
        @(posedge clk);

        if (count !== 4) begin
            $display("ERROR: Expected count=4, got %0d", count);
            error_count++;
        end

        // Now do simultaneous read/write
        for (int i = 0; i < 8; i++) begin
            wr_data = 8'hB0 + i;
            wr_en = 1;
            rd_en = 1;
            @(posedge clk);
        end

        wr_en = 0;
        rd_en = 0;
        @(posedge clk);

        if (count !== 8) begin
            $display("ERROR: Count should remain at 8 during simultaneous ops, got %0d", count);
            error_count++;
        end

        $display("PASS: Simultaneous read/write test completed\n");
        test_count++;
    endtask

    task test_write_when_full();
        $display("TEST: Ignore writes when full");

        // Fill the FIFO
        for (int i = 0; i < 8; i++) begin
            wr_data = i;
            wr_en = 1;
            @(posedge clk);
        end

        wr_en = 0;
        @(posedge clk);

        if (full !== 1'b1) begin
            $display("ERROR: FIFO should be full");
            error_count++;
        end

        // Try to write while full - should be ignored
        wr_data = 8'hFF;
        wr_en = 1;
        @(posedge clk);
        wr_en = 0;
        @(posedge clk);

        // Read one item to verify the last item is still 7
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        @(posedge clk);

        // The next read should give us 1 (second element)
        rd_en = 1;
        @(posedge clk);
        if (rd_data !== 8'h01) begin
            $display("ERROR: Expected to read 0x01, got 0x%02x", rd_data);
            error_count++;
        end
        rd_en = 0;

        $display("PASS: Write when full test completed\n");
        test_count++;
    endtask

    task test_read_when_empty();
        $display("TEST: Ignore reads when empty");

        // FIFO should be empty after reset
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        @(posedge clk);

        if (empty !== 1'b1) begin
            $display("ERROR: FIFO should be empty");
            error_count++;
        end

        $display("PASS: Read when empty test completed\n");
        test_count++;
    endtask

    initial begin
        test_reset();
        test_write_full();
        test_read_empty();

        test_reset();
        test_simultaneous_rw();

        test_reset();
        test_write_when_full();

        test_reset();
        test_read_when_empty();

        #100;

        $display("\n================================");
        $display("Test Results:");
        $display("  Total tests: %0d", test_count);
        $display("  Errors: %0d", error_count);
        if (error_count == 0)
            $display("  Status: ALL TESTS PASSED!");
        else
            $display("  Status: SOME TESTS FAILED!");
        $display("================================\n");

        $finish;
    end

endmodule
