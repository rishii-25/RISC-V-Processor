// riscv_top.v
// Single-cycle RV32I core (Phase 1 subset): ADD, SUB, ADDI, AND, OR, XOR,
// LW, SW, BEQ, JAL, JALR, LUI.
//
// Everything — fetch, decode, execute, memory access, writeback — happens
// combinationally within one clock period; only the PC and the register
// file / data memory contents are stateful (synchronous).

module riscv_top #(
    parameter IMEM_FILE  = "programs/test_program.hex",
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256
) (
    input wire clk,
    input wire rst
);

    // ---------------- Fetch ----------------
    wire [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    wire [31:0] instr;

    program_counter PC_REG (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    assign pc_plus4 = pc + 32'd4;

    instruction_memory #(
        .MEM_FILE  (IMEM_FILE),
        .MEM_WORDS (IMEM_WORDS)
    ) IMEM (
        .pc    (pc),
        .instr (instr)
    );

    // ---------------- Decode ----------------
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd_addr  = instr[11:7];
    wire [2:0] funct3   = instr[14:12];
    wire [4:0] rs1_addr = instr[19:15];
    wire [4:0] rs2_addr = instr[24:20];
    wire [6:0] funct7   = instr[31:25];

    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        alu_src_a;
    wire        alu_src_b;
    wire [3:0]  alu_control;
    wire [2:0]  imm_type;
    wire        branch;
    wire        jump;
    wire        jalr;
    wire [1:0]  result_src;

    control_unit CTRL (
        .opcode      (opcode),
        .funct3      (funct3),
        .funct7      (funct7),
        .reg_write   (reg_write),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .alu_src_a   (alu_src_a),
        .alu_src_b   (alu_src_b),
        .alu_control (alu_control),
        .imm_type    (imm_type),
        .branch      (branch),
        .jump        (jump),
        .jalr        (jalr),
        .result_src  (result_src)
    );

    wire [31:0] rs1_data, rs2_data;
    wire [31:0] rd_data;

    register_file REGFILE (
        .clk       (clk),
        .rst       (rst),
        .rs1_addr  (rs1_addr),
        .rs2_addr  (rs2_addr),
        .rd_addr   (rd_addr),
        .rd_data   (rd_data),
        .reg_write (reg_write),
        .rs1_data  (rs1_data),
        .rs2_data  (rs2_data)
    );

    wire [31:0] imm_out;

    immediate_generator IMMGEN (
        .instr    (instr),
        .imm_type (imm_type),
        .imm_out  (imm_out)
    );

    // ---------------- Execute ----------------
    wire [31:0] alu_operand_a = alu_src_a ? 32'h0 : rs1_data;
    wire [31:0] alu_operand_b = alu_src_b ? imm_out : rs2_data;

    wire [31:0] alu_result;
    wire        alu_zero;

    alu ALU (
        .operand_a   (alu_operand_a),
        .operand_b   (alu_operand_b),
        .alu_control (alu_control),
        .result      (alu_result),
        .zero        (alu_zero)
    );

    // branch / jump target computation
    wire [31:0] branch_target = pc + imm_out;          // BEQ
    wire [31:0] jal_target    = pc + imm_out;          // JAL
    wire [31:0] jalr_target   = (rs1_data + imm_out) & ~32'h1; // JALR, LSB cleared per spec

    wire take_branch = branch & alu_zero;

    assign pc_next = jalr        ? jalr_target   :
                      jump        ? jal_target    :
                      take_branch ? branch_target :
                                    pc_plus4;

    // ---------------- Memory ----------------
    wire [31:0] mem_read_data;

    data_memory #(
        .MEM_WORDS (DMEM_WORDS)
    ) DMEM (
        .clk        (clk),
        .addr       (alu_result),   // base + offset computed by ALU
        .write_data (rs2_data),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .read_data  (mem_read_data)
    );

    // ---------------- Writeback ----------------
    assign rd_data = (result_src == 2'b01) ? mem_read_data :
                      (result_src == 2'b10) ? pc_plus4      :
                                               alu_result;

endmodule
