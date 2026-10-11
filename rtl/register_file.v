// register_file.v
// 32 x 32-bit RV32I register file. x0 is hardwired to zero (writes to it
// are discarded). Reads are combinational (asynchronous); writes commit
// synchronously on the rising clock edge, which is what makes this a
// correct single-cycle design: the instruction currently being decoded
// always reads the architectural state as of the *previous* instruction's
// writeback, never its own.

module register_file (
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    input  wire        reg_write,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

    reg [31:0] regs [1:31]; // x0 excluded; always reads as zero
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 1; i <= 31; i = i + 1)
                regs[i] <= 32'h0;
        end else if (reg_write && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end

    assign rs1_data = (rs1_addr == 5'd0) ? 32'h0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'h0 : regs[rs2_addr];

endmodule
