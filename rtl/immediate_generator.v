// immediate_generator.v
// Sign-extends and reassembles the five RV32I immediate encodings.
// imm_type is produced by the control unit from the opcode.

module immediate_generator (
    input  wire [31:0] instr,
    input  wire [2:0]  imm_type,
    output reg  [31:0] imm_out
);

    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    always @(*) begin
        case (imm_type)
            IMM_I: imm_out = {{20{instr[31]}}, instr[31:20]};

            IMM_S: imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            IMM_B: imm_out = {{19{instr[31]}}, instr[31], instr[7],
                               instr[30:25], instr[11:8], 1'b0};

            IMM_U: imm_out = {instr[31:12], 12'b0};

            IMM_J: imm_out = {{11{instr[31]}}, instr[31], instr[19:12],
                               instr[20], instr[30:21], 1'b0};

            default: imm_out = 32'h0;
        endcase
    end

endmodule
