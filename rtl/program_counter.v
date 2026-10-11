// program_counter.v
// Simple PC register: updates to pc_next on every rising clock edge,
// resets to 0 (reset vector) on reset.

module program_counter (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

endmodule
