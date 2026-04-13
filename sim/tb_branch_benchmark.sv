module tb_branch_benchmark import rv32i_pkg::*; ();
  localparam logic [31:0] EXPECTED_FINAL_PC = 32'h0000_007C;
  localparam int MAX_WAIT_PC = 1024;
  localparam int DRAIN_CYCLES = 12;

  logic clk_w;
  logic rst_w;
  logic imem_write_en_w;
  logic [31:0] imem_write_addr_w;
  logic [31:0] imem_write_data_w;

  rv32i_cpu #(
    .IMEM_SIZE (256),
    .DMEM_SIZE (256)
  ) u_rv32i_cpu (
    .clk_i (clk_w),
    .rst_i (rst_w),
    .imem_write_en_i (imem_write_en_w),
    .imem_write_addr_i (imem_write_addr_w),
    .imem_write_data_i (imem_write_data_w)
  );

  int test_count_r = 0;
  int pass_count_r = 0;

  initial clk_w = 0;
  always #5 clk_w = ~clk_w;

  initial begin
    if ($test$plusargs("vcd")) begin
      $dumpfile("sim/tb_branch_benchmark.vcd");
      $dumpvars(0, tb_branch_benchmark);
    end
  end

  task automatic load_word(
    input logic [31:0] addr,
    input logic [31:0] data
  );
    imem_write_addr_w = addr;
    imem_write_data_w = data;
    imem_write_en_w = 1'b1;
    @(posedge clk_w);
    #1;
    imem_write_en_w = 1'b0;
  endtask

  task automatic check_reg(
    input string name,
    input int reg_idx,
    input logic [31:0] expected
  );
    logic [31:0] actual;
    actual = u_rv32i_cpu.u_register_file.regs_r[reg_idx];
    test_count_r++;
    if (actual === expected) begin
      pass_count_r++;
    end else begin
      $display("FAIL: %s x%0d=0x%08h expected=0x%08h", name, reg_idx, actual, expected);
    end
  endtask

  task automatic load_branch_program;
    // Test 1: sum(1..10) backward loop, x10 = 55
    // 9 taken backward BNE, 1 not taken
    load_word(32'h00, 32'h00000513); // ADDI x10, x0, 0
    load_word(32'h04, 32'h00A00093); // ADDI x1, x0, 10
    load_word(32'h08, 32'h00150533); // ADD  x10, x10, x1
    load_word(32'h0C, 32'hFFF08093); // ADDI x1, x1, -1
    load_word(32'h10, 32'hFE009CE3); // BNE  x1, x0, -8

    // Test 2: nested loop 6*7, x11 = 42
    // Inner BNE: 36 taken, 6 not taken
    // Outer BNE: 5 taken, 1 not taken
    load_word(32'h14, 32'h00000593); // ADDI x11, x0, 0
    load_word(32'h18, 32'h00600113); // ADDI x2, x0, 6
    load_word(32'h1C, 32'h00700193); // ADDI x3, x0, 7
    load_word(32'h20, 32'h00018233); // ADD  x4, x3, x0  (outer top)
    load_word(32'h24, 32'h00158593); // ADDI x11, x11, 1 (inner top)
    load_word(32'h28, 32'hFFF20213); // ADDI x4, x4, -1
    load_word(32'h2C, 32'hFE021CE3); // BNE  x4, x0, -8
    load_word(32'h30, 32'hFFF10113); // ADDI x2, x2, -1
    load_word(32'h34, 32'hFE0116E3); // BNE  x2, x0, -20

    // Test 3: forward branches (if-else), x12 = 11
    // BEQ not taken, BEQ taken forward, BEQ taken forward
    load_word(32'h38, 32'h00300293); // ADDI x5, x0, 3
    load_word(32'h3C, 32'h00000613); // ADDI x12, x0, 0
    load_word(32'h40, 32'h00028663); // BEQ  x5, x0, +12 (not taken)
    load_word(32'h44, 32'h00A60613); // ADDI x12, x12, 10
    load_word(32'h48, 32'h00000463); // BEQ  x0, x0, +8 (taken)
    load_word(32'h4C, 32'h06460613); // ADDI x12, x12, 100 (skipped)
    load_word(32'h50, 32'h00000293); // ADDI x5, x0, 0
    load_word(32'h54, 32'h00028463); // BEQ  x5, x0, +8 (taken)
    load_word(32'h58, 32'h3E860613); // ADDI x12, x12, 1000 (skipped)
    load_word(32'h5C, 32'h00160613); // ADDI x12, x12, 1

    // Test 4: JAL/JALR subroutine, x13 = 101
    // 3 unconditional jumps (JAL, JALR, JAL)
    load_word(32'h60, 32'h00000693); // ADDI x13, x0, 0
    load_word(32'h64, 32'h00C000EF); // JAL  x1, +12
    load_word(32'h68, 32'h00168693); // ADDI x13, x13, 1 (after return)
    load_word(32'h6C, 32'h00C0006F); // JAL  x0, +12
    load_word(32'h70, 32'h06468693); // ADDI x13, x13, 100 (subroutine)
    load_word(32'h74, 32'h00008067); // JALR x0, x1, 0 (return)
    load_word(32'h78, 32'h00000013); // NOP (end sentinel)
  endtask

  task automatic verify_results;
    check_reg("sum(1..10)", 10, 32'd55);
    check_reg("6*7 nested", 11, 32'd42);
    check_reg("fwd branch", 12, 32'd11);
    check_reg("JAL/JALR", 13, 32'd101);
  endtask

  task automatic assert_invariants;
    if (u_rv32i_cpu.u_register_file.regs_r[0] !== 32'h0)
      $error("ASSERT: x0 must stay 0");
  endtask

  initial begin
    int cycle_count;

    rst_w = 1'b1;
    imem_write_en_w = 1'b0;
    imem_write_addr_w = 32'b0;
    imem_write_data_w = 32'b0;
    @(posedge clk_w);
    #1;

    load_branch_program();

    rst_w = 1'b0;
    cycle_count = 0;

    begin : wait_for_fetch_pc
      while (u_rv32i_cpu.pc_r !== EXPECTED_FINAL_PC && cycle_count < MAX_WAIT_PC) begin
        @(posedge clk_w);
        cycle_count++;
      end
      if (cycle_count >= MAX_WAIT_PC) begin
        $fatal(1, "timeout: pc_r never reached 0x%08h (last seen 0x%08h)", EXPECTED_FINAL_PC, u_rv32i_cpu.pc_r);
      end
    end

    repeat (DRAIN_CYCLES) @(posedge clk_w);
    cycle_count = cycle_count + DRAIN_CYCLES;
    #1;

    verify_results();
    assert_invariants();

    $display("Branch stats:");
    $display("backward taken:      50 (9 simple + 36 inner + 5 outer)");
    $display("backward not taken:  8  (1 simple + 6 inner + 1 outer)");
    $display("forward taken:       2");
    $display("forward not taken:   1");
    $display("unconditional jumps: 3  (2 JAL + 1 JALR)");
    $display("total taken:         55\n");

    $display("Cycles: %0d\n", cycle_count);

    $display("PASSED: %0d", pass_count_r);
    $display("FAILED: %0d", test_count_r - pass_count_r);

    $finish;
  end

endmodule
