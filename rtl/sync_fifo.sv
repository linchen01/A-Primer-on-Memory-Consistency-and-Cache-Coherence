// Synchronous FIFO with depth of 8
// Data width is configurable via parameter
module sync_fifo #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 8
) (
    input  logic                 clk,
    input  logic                 rst_n,

    // Write port
    input  logic                 wr_en,
    input  logic [WIDTH-1:0]     wr_data,
    output logic                 full,

    // Read port
    input  logic                 rd_en,
    output logic [WIDTH-1:0]     rd_data,
    output logic                 empty,

    // Status signals
    output logic [$clog2(DEPTH):0] count
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [WIDTH-1:0] fifo_mem [DEPTH-1:0];
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [ADDR_WIDTH:0] wr_ptr_next, rd_ptr_next;

    // Pointer calculation
    assign wr_ptr_next = wr_ptr + 1;
    assign rd_ptr_next = rd_ptr + 1;

    // Empty/Full logic
    // FIFO is full when write pointer + 1 equals read pointer (MSB differs, address same)
    // FIFO is empty when both pointers are equal
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr_next[ADDR_WIDTH-1:0] == rd_ptr) &&
                   (wr_ptr_next[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]);

    // Count calculation
    logic [ADDR_WIDTH:0] wr_ptr_ext, rd_ptr_ext;
    assign wr_ptr_ext = {1'b0, wr_ptr};
    assign rd_ptr_ext = {1'b0, rd_ptr};

    always_comb begin
        if (wr_ptr_ext >= rd_ptr_ext)
            count = wr_ptr_ext - rd_ptr_ext;
        else
            count = (DEPTH - rd_ptr_ext) + wr_ptr_ext;
    end

    // Write operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            fifo_mem <= '{default: '0};
        end else begin
            if (wr_en && !full) begin
                fifo_mem[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr_next[ADDR_WIDTH-1:0];
            end
        end
    end

    // Read operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end else begin
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr_next[ADDR_WIDTH-1:0];
            end
        end
    end

    // Read data combinatorial output
    assign rd_data = fifo_mem[rd_ptr];

endmodule
