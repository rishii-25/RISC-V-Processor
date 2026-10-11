// tb_riscv_top.v
// Self-checking testbench for the Phase 1 single-cycle core.
// Runs programs/test_program.hex (see sim/assemble.py for the source
// listing) and checks final register file + data memory state against
// hand-computed expected values. Reports PASS/FAIL per check and a
// summary; exits nonzero on any failure so it's CI-friendly.

`timescale 1ns / 1ps

module tb_riscv_top;

    reg clk;
    reg rst;

    integer errors;
    integer checks;

    riscv_top #(
        .IMEM_FILE  ("programs/test_program.hex"),
        .IMEM_WORDS (256),
        .DMEM_WORDS (256)
    ) DUT (
        .clk (clk),
        .rst (rst)
    );

    // 100 MHz-equivalent clock, period irrelevant for a single-cycle
    // functional sim — just needs to toggle.
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- register / memory check helper --------------------------------
    task check_reg;
        input [255:0] name;   // label for display
        input [4:0]   idx;
        input [31:0]  expected;
        reg   [31:0]  actual;
        begin
            actual = (idx == 0) ? 32'h0 : DUT.REGFILE.regs[idx];
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL  %0s = 0x%08h, expected 0x%08h", name, actual, expected);
            end else begin
                $display("PASS  %0s = 0x%08h", name, actual);
            end
        end
    endtask

    task check_mem;
        input [255:0] name;
        input [31:0]  word_idx;
        input [31:0]  expected;
        reg   [31:0]  actual;
        begin
            actual = DUT.DMEM.mem[word_idx];
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL  %0s = 0x%08h, expected 0x%08h", name, actual, expected);
            end else begin
                $display("PASS  %0s = 0x%08h", name, actual);
            end
        end
    endtask

    initial begin
        $dumpfile("sim/tb_riscv_top.vcd");
        $dumpvars(0, tb_riscv_top);

        errors = 0;
        checks = 0;

        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;

        // 23 instructions, no loops before the deliberate halt at idx22 ->
        // 30 cycles is ample margin.
        repeat (30) @(posedge clk);

        $display("----------------------------------------------------");
        $display("Final PC = 0x%08h (expect 0x00000058, halt loop)", DUT.pc);
        $display("----------------------------------------------------");

        // Arithmetic / logical
        check_reg("x1  (ADDI 5)       ", 1,  32'd5);
        check_reg("x2  (ADDI 10)      ", 2,  32'd10);
        check_reg("x3  (ADD)          ", 3,  32'd15);
        check_reg("x4  (SUB)          ", 4,  32'd5);
        check_reg("x5  (AND)          ", 5,  32'd0);
        check_reg("x6  (OR)           ", 6,  32'd15);
        check_reg("x7  (XOR)          ", 7,  32'd15);

        // Memory round-trip
        check_reg("x8  (LW)           ", 8,  32'd15);
        check_mem("mem[0] (SW)        ", 0,  32'd15);

        // LUI
        check_reg("x9  (LUI)          ", 9,  32'h12345000);

        // BEQ taken: x10 must be 111, NOT 999 (999 write must be skipped)
        check_reg("x10 (BEQ taken)    ", 10, 32'd111);

        // BEQ not taken: x11 must be 222 (fallthrough executed)
        check_reg("x11 (BEQ not-taken)", 11, 32'd222);

        // JAL: link register and skip check
        check_reg("x12 (JAL link)     ", 12, 32'd64);
        check_reg("x16 (JAL skip)     ", 16, 32'd0);     // never written
        check_reg("x17 (JAL target)   ", 17, 32'd77);

        // JALR: link register and target check
        check_reg("x18 (jalr addr src)", 18, 32'd84);
        check_reg("x19 (JALR link)    ", 19, 32'd84);
        check_reg("x20 (JALR target)  ", 20, 32'd55);

        // Halt loop reached and holding
        if (DUT.pc !== 32'h00000058) begin
            errors = errors + 1;
            $display("FAIL  final PC = 0x%08h, expected 0x00000058", DUT.pc);
        end
        checks = checks + 1;

        $display("----------------------------------------------------");
        if (errors == 0)
            $display("ALL %0d CHECKS PASSED", checks);
        else
            $display("%0d of %0d CHECKS FAILED", errors, checks);
        $display("----------------------------------------------------");

        if (errors != 0)
            $fatal(1, "Testbench failed");

        $finish;
    end

endmodule
