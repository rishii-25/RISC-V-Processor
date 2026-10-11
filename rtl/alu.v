// alu.v
// Combinational ALU. alu_control selects the operation; zero flag feeds
// branch resolution (BEQ: taken when SUB result == 0).

module alu (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result,
    output wire         zero
);

    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_PASSB = 4'b0101; // used for LUI

    always @(*) begin
        case (alu_control)
            ALU_ADD:   result = operand_a + operand_b;
            ALU_SUB:   result = operand_a - operand_b;
            ALU_AND:   result = operand_a & operand_b;
            ALU_OR:    result = operand_a | operand_b;
            ALU_XOR:   result = operand_a ^ operand_b;
            ALU_PASSB: result = operand_b;
            default:   result = 32'h0;
        endcase
    end

    assign zero = (result == 32'h0);

endmodule
