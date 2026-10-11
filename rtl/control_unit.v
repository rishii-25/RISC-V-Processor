// control_unit.v
// Decodes opcode/funct3/funct7 into every datapath control signal.
// Covers: ADD, SUB, ADDI, AND, OR, XOR, LW, SW, BEQ, JAL, JALR, LUI.
// (JALR added alongside the planned subset — needed for any real
// function-call test program and reuses the same I-type immediate path.)

module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src_a,   // 0 = rs1, 1 = zero   (zero only for LUI)
    output reg        alu_src_b,   // 0 = rs2, 1 = imm
    output reg [3:0]  alu_control,
    output reg [2:0]  imm_type,
    output reg        branch,      // BEQ
    output reg        jump,        // JAL
    output reg        jalr,        // JALR
    output reg [1:0]  result_src   // 00 = ALU, 01 = mem, 10 = PC+4 (link)
);

    // opcodes
    localparam OP_R      = 7'b0110011;
    localparam OP_I_ALU  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;

    // imm_type encoding (must match immediate_generator.v)
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    // alu_control encoding (must match alu.v)
    localparam ALU_ADD   = 4'b0000;
    localparam ALU_SUB   = 4'b0001;
    localparam ALU_AND   = 4'b0010;
    localparam ALU_OR    = 4'b0011;
    localparam ALU_XOR   = 4'b0100;
    localparam ALU_PASSB = 4'b0101;

    always @(*) begin
        // safe defaults (NOP-like; also covers unimplemented opcodes)
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        alu_src_a   = 1'b0;
        alu_src_b   = 1'b0;
        alu_control = ALU_ADD;
        imm_type    = IMM_I;
        branch      = 1'b0;
        jump        = 1'b0;
        jalr        = 1'b0;
        result_src  = 2'b00;

        case (opcode)

            OP_R: begin
                reg_write  = 1'b1;
                alu_src_a  = 1'b0;
                alu_src_b  = 1'b0; // rs2
                result_src = 2'b00;
                case (funct3)
                    3'b000:  alu_control = funct7[5] ? ALU_SUB : ALU_ADD; // SUB / ADD
                    3'b111:  alu_control = ALU_AND;
                    3'b110:  alu_control = ALU_OR;
                    3'b100:  alu_control = ALU_XOR;
                    default: alu_control = ALU_ADD;
                endcase
            end

            OP_I_ALU: begin // ADDI (and room for ANDI/ORI/XORI later)
                reg_write  = 1'b1;
                alu_src_a  = 1'b0;
                alu_src_b  = 1'b1; // imm
                imm_type   = IMM_I;
                result_src = 2'b00;
                case (funct3)
                    3'b000:  alu_control = ALU_ADD; // ADDI
                    3'b111:  alu_control = ALU_AND;
                    3'b110:  alu_control = ALU_OR;
                    3'b100:  alu_control = ALU_XOR;
                    default: alu_control = ALU_ADD;
                endcase
            end

            OP_LOAD: begin // LW
                reg_write   = 1'b1;
                mem_read    = 1'b1;
                alu_src_a   = 1'b0;
                alu_src_b   = 1'b1; // imm, for address calc
                alu_control = ALU_ADD;
                imm_type    = IMM_I;
                result_src  = 2'b01; // mem data
            end

            OP_STORE: begin // SW
                mem_write   = 1'b1;
                alu_src_a   = 1'b0;
                alu_src_b   = 1'b1; // imm, for address calc
                alu_control = ALU_ADD;
                imm_type    = IMM_S;
            end

            OP_BRANCH: begin // BEQ
                branch      = 1'b1;
                alu_src_a   = 1'b0;
                alu_src_b   = 1'b0; // rs2, compare via SUB
                alu_control = ALU_SUB;
                imm_type    = IMM_B;
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                imm_type   = IMM_J;
                result_src = 2'b10; // link: PC+4
            end

            OP_JALR: begin
                reg_write   = 1'b1;
                jalr        = 1'b1;
                alu_src_a   = 1'b0;
                alu_src_b   = 1'b1; // imm, target = rs1 + imm
                alu_control = ALU_ADD;
                imm_type    = IMM_I;
                result_src  = 2'b10; // link: PC+4
            end

            OP_LUI: begin
                reg_write   = 1'b1;
                alu_src_a   = 1'b1; // zero
                alu_src_b   = 1'b1; // imm
                alu_control = ALU_PASSB;
                imm_type    = IMM_U;
                result_src  = 2'b00;
            end

            default: ; // NOP / unimplemented: everything stays at safe defaults
        endcase
    end

endmodule
