// instruction_memory.v
// Word-addressed instruction ROM, loaded from a hex file at elaboration time.
// MEM_FILE is a parameter so the testbench can point it at different test
// programs without editing this module.

module instruction_memory #(
    parameter MEM_FILE  = "programs/test_program.hex",
    parameter MEM_WORDS = 256
) (
    input  wire [31:0] pc,
    output wire [31:0] instr
);

    reg [31:0] mem [0:MEM_WORDS-1];

    initial begin
        $readmemh(MEM_FILE, mem);
    end

    // word-aligned access: ignore byte offset bits [1:0]
    assign instr = mem[pc[31:2]];

endmodule
