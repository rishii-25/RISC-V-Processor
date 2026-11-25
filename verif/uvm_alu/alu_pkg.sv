// alu_pkg.sv
// UVM verification environment for rtl/alu.v
//
//   test -> env -> agent (sequencer, driver, monitor)
//                -> scoreboard (reference model, checks result + zero flag)
//                -> coverage   (operation x operand-class bins, zero flag)
//
// Tests: alu_random_test (constrained-random), alu_corner_test (directed
// corner values for every operation, including unused opcodes).

package alu_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Opcodes, matching rtl/alu.v and rtl/control_unit.v
    typedef enum logic [3:0] {
        ALU_ADD   = 4'b0000,
        ALU_SUB   = 4'b0001,
        ALU_AND   = 4'b0010,
        ALU_OR    = 4'b0011,
        ALU_XOR   = 4'b0100,
        ALU_PASSB = 4'b0101
    } alu_op_e;

    localparam int NUM_CTRL = 16;  // all 4-bit encodings, 6 legal + 10 unused

    // ------------------------------------------------------------------ //
    // Transaction
    // ------------------------------------------------------------------ //
    class alu_txn extends uvm_sequence_item;
        rand logic [31:0] operand_a;
        rand logic [31:0] operand_b;
        rand logic [3:0]  alu_control;
        logic [31:0]      result;   // filled in by the monitor
        logic             zero;

        // Mostly legal ops, occasionally an unused encoding (ALU must output 0)
        constraint c_ctrl {
            alu_control dist { [4'd0:4'd5] :/ 90, [4'd6:4'd15] :/ 10 };
        }
        // Bias operands towards the values where adders and flags break
        constraint c_corner_a {
            operand_a dist { 32'h0 := 5, 32'hFFFF_FFFF := 5, 32'h7FFF_FFFF := 5,
                             32'h8000_0000 := 5, 32'h1 := 5, [0:32'hFFFF_FFFF] :/ 75 };
        }
        constraint c_corner_b {
            operand_b dist { 32'h0 := 5, 32'hFFFF_FFFF := 5, 32'h7FFF_FFFF := 5,
                             32'h8000_0000 := 5, 32'h1 := 5, [0:32'hFFFF_FFFF] :/ 75 };
        }

        `uvm_object_utils_begin(alu_txn)
            `uvm_field_int(operand_a,   UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(operand_b,   UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(alu_control, UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(result,      UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(zero,        UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "alu_txn");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("ctrl=%0h a=%08h b=%08h -> result=%08h zero=%0b",
                             alu_control, operand_a, operand_b, result, zero);
        endfunction
    endclass

    // ------------------------------------------------------------------ //
    // Sequences
    // ------------------------------------------------------------------ //
    class alu_random_seq extends uvm_sequence #(alu_txn);
        `uvm_object_utils(alu_random_seq)
        int unsigned n_items = 2000;

        function new(string name = "alu_random_seq");
            super.new(name);
        endfunction

        task body();
            alu_txn t;
            repeat (n_items) begin
                t = alu_txn::type_id::create("t");
                start_item(t);
                if (!t.randomize()) `uvm_fatal("RAND", "randomize failed")
                finish_item(t);
            end
        endtask
    endclass

    // Every opcode (including the 10 unused ones) against every pair of corner values
    class alu_corner_seq extends uvm_sequence #(alu_txn);
        `uvm_object_utils(alu_corner_seq)

        function new(string name = "alu_corner_seq");
            super.new(name);
        endfunction

        task body();
            logic [31:0] corners[$] = '{32'h0, 32'h1, 32'hFFFF_FFFF, 32'h7FFF_FFFF,
                                        32'h8000_0000, 32'hAAAA_AAAA, 32'h5555_5555};
            alu_txn t;
            for (int c = 0; c < NUM_CTRL; c++)
                foreach (corners[i])
                    foreach (corners[j]) begin
                        t = alu_txn::type_id::create("t");
                        start_item(t);
                        t.alu_control = c[3:0];
                        t.operand_a   = corners[i];
                        t.operand_b   = corners[j];
                        finish_item(t);
                    end
        endtask
    endclass

    // ------------------------------------------------------------------ //
    // Driver: applies a transaction on each rising clock edge
    // ------------------------------------------------------------------ //
    class alu_driver extends uvm_driver #(alu_txn);
        `uvm_component_utils(alu_driver)
        virtual alu_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "virtual interface not set")
        endfunction

        // One transaction per clock; valid drops when the sequencer has nothing,
        // so the monitor never samples the same transaction twice.
        task run_phase(uvm_phase phase);
            vif.valid <= 1'b0;
            forever begin
                @(posedge vif.clk);
                seq_item_port.try_next_item(req);
                if (req != null) begin
                    vif.operand_a   <= req.operand_a;
                    vif.operand_b   <= req.operand_b;
                    vif.alu_control <= req.alu_control;
                    vif.valid       <= 1'b1;
                    seq_item_port.item_done();
                end else begin
                    vif.valid       <= 1'b0;
                end
            end
        endtask
    endclass

    // ------------------------------------------------------------------ //
    // Monitor: samples inputs and outputs on the falling edge
    // ------------------------------------------------------------------ //
    class alu_monitor extends uvm_monitor;
        `uvm_component_utils(alu_monitor)
        virtual alu_if vif;
        uvm_analysis_port #(alu_txn) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "virtual interface not set")
        endfunction

        task run_phase(uvm_phase phase);
            alu_txn t;
            forever begin
                @(negedge vif.clk);
                if (vif.valid) begin
                    t = alu_txn::type_id::create("mon_t");
                    t.operand_a   = vif.operand_a;
                    t.operand_b   = vif.operand_b;
                    t.alu_control = vif.alu_control;
                    t.result      = vif.result;
                    t.zero        = vif.zero;
                    ap.write(t);
                end
            end
        endtask
    endclass

    // ------------------------------------------------------------------ //
    // Agent
    // ------------------------------------------------------------------ //
    class alu_agent extends uvm_agent;
        `uvm_component_utils(alu_agent)
        uvm_sequencer #(alu_txn) sqr;
        alu_driver  drv;
        alu_monitor mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = uvm_sequencer#(alu_txn)::type_id::create("sqr", this);
            drv = alu_driver::type_id::create("drv", this);
            mon = alu_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    // ------------------------------------------------------------------ //
    // Scoreboard: golden reference model, checks result and zero flag
    // ------------------------------------------------------------------ //
    class alu_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(alu_scoreboard)
        uvm_analysis_imp #(alu_txn, alu_scoreboard) imp;
        int unsigned n_checked, n_errors;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            imp = new("imp", this);
        endfunction

        // Reference model: written from the RV32I spec, independent of the RTL
        static function logic [31:0] ref_result(logic [3:0] ctrl, logic [31:0] a, logic [31:0] b);
            case (ctrl)
                ALU_ADD:   return a + b;
                ALU_SUB:   return a - b;
                ALU_AND:   return a & b;
                ALU_OR:    return a | b;
                ALU_XOR:   return a ^ b;
                ALU_PASSB: return b;
                default:   return 32'h0;
            endcase
        endfunction

        function void write(alu_txn t);
            logic [31:0] exp_res = ref_result(t.alu_control, t.operand_a, t.operand_b);
            logic        exp_zero = (exp_res == 32'h0);
            n_checked++;
            if (t.result !== exp_res || t.zero !== exp_zero) begin
                n_errors++;
                `uvm_error("MISMATCH", $sformatf("%s | expected result=%08h zero=%0b",
                                                 t.convert2string(), exp_res, exp_zero))
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SCOREBOARD", $sformatf("%0d transactions checked, %0d mismatches",
                                              n_checked, n_errors), UVM_NONE)
        endfunction
    endclass

    // ------------------------------------------------------------------ //
    // Functional coverage
    // Bins: 16 opcodes x 4 classes for operand A x 4 classes for operand B,
    // plus zero flag 0/1 for each legal opcode. Counted with arrays so the
    // report works on every simulator (some tools ignore covergroups).
    // ------------------------------------------------------------------ //
    class alu_coverage extends uvm_subscriber #(alu_txn);
        `uvm_component_utils(alu_coverage)

        bit hit_op_ab[NUM_CTRL][4][4];
        bit hit_zero[6][2];

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // 0 = zero, 1 = all ones, 2 = sign-boundary (7FFFFFFF / 80000000), 3 = other
        static function int cls(logic [31:0] v);
            if (v == 32'h0)                               return 0;
            if (v == 32'hFFFF_FFFF)                       return 1;
            if (v == 32'h7FFF_FFFF || v == 32'h8000_0000) return 2;
            return 3;
        endfunction

        function void write(alu_txn t);
            hit_op_ab[t.alu_control][cls(t.operand_a)][cls(t.operand_b)] = 1'b1;
            if (t.alu_control <= 4'd5) hit_zero[t.alu_control][t.zero] = 1'b1;
        endfunction

        function real pct_op_ab();
            int hits = 0;
            foreach (hit_op_ab[i, j, k]) hits += hit_op_ab[i][j][k];
            return 100.0 * hits / (NUM_CTRL * 4 * 4);
        endfunction

        function real pct_zero();
            int hits = 0, total = 0;
            for (int op = 0; op < 6; op++)
                for (int z = 0; z < 2; z++) begin
                    total++;
                    hits += hit_zero[op][z];
                end
            return 100.0 * hits / total;
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("COVERAGE", $sformatf("opcode x operand-class: %0.1f%% | zero flag per opcode: %0.1f%%",
                                            pct_op_ab(), pct_zero()), UVM_NONE)
        endfunction
    endclass

    // ------------------------------------------------------------------ //
    // Environment
    // ------------------------------------------------------------------ //
    class alu_env extends uvm_env;
        `uvm_component_utils(alu_env)
        alu_agent      agt;
        alu_scoreboard sb;
        alu_coverage   cov;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = alu_agent::type_id::create("agt", this);
            sb  = alu_scoreboard::type_id::create("sb", this);
            cov = alu_coverage::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            agt.mon.ap.connect(sb.imp);
            agt.mon.ap.connect(cov.analysis_export);
        endfunction
    endclass

    // ------------------------------------------------------------------ //
    // Tests
    // ------------------------------------------------------------------ //
    class alu_base_test extends uvm_test;
        `uvm_component_utils(alu_base_test)
        alu_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = alu_env::type_id::create("env", this);
        endfunction

        virtual task run_seq();
        endtask

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            run_seq();
            // let the last transaction reach the monitor
            repeat (2) @(posedge env.agt.drv.vif.clk);
            phase.drop_objection(this);
        endtask

        function void report_phase(uvm_phase phase);
            uvm_report_server rs = uvm_report_server::get_server();
            if (rs.get_severity_count(UVM_ERROR) + rs.get_severity_count(UVM_FATAL) == 0)
                `uvm_info("RESULT", "*** TEST PASSED ***", UVM_NONE)
            else
                `uvm_info("RESULT", "*** TEST FAILED ***", UVM_NONE)
        endfunction
    endclass

    class alu_random_test extends alu_base_test;
        `uvm_component_utils(alu_random_test)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
        task run_seq();
            alu_random_seq s = alu_random_seq::type_id::create("s");
            s.start(env.agt.sqr);
        endtask
    endclass

    class alu_corner_test extends alu_base_test;
        `uvm_component_utils(alu_corner_test)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
        task run_seq();
            alu_corner_seq c = alu_corner_seq::type_id::create("c");
            alu_random_seq r = alu_random_seq::type_id::create("r");
            c.start(env.agt.sqr);
            r.n_items = 500;
            r.start(env.agt.sqr);
        endtask
    endclass
endpackage
