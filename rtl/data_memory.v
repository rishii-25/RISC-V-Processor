// data_memory.v
// Word-addressed data RAM for LW/SW. Synchronous write, asynchronous read
// (typical for a single-cycle design — the read result must be ready
// combinationally within the same cycle for MemToReg muxing).

module data_memory #(
    parameter MEM_WORDS = 256
) (
    input  wire        clk,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    input  wire        mem_write,
    input  wire        mem_read,
    output wire [31:0] read_data
);

    reg [31:0] mem [0:MEM_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'h0;
    end

    always @(posedge clk) begin
        if (mem_write)
            mem[addr[31:2]] <= write_data;
    end

    assign read_data = mem_read ? mem[addr[31:2]] : 32'h0;

endmodule
