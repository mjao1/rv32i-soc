module tb_rv32i_cpu import rv32i_pkg::*; ();
  localparam int NUM_INSTR_EXECUTED = 11;
  localparam logic [31:0] EXPECTED_FINAL_PC = 32'h0000_0030; // after last instr at 0x2C, PC is 0x30
  localparam int MAX_WAIT_PC = 256;
  localparam int DRAIN_CYCLES = 12;

  logic clk_w;
  logic rst_w;
  logic imem_write_en_w;
  logic [31:0] imem_write_addr_w;
  logic [31:0] imem_write_data_w;

  wire [31:0] ex_mem_alu_res_nc;
  wire ex_mem_mem_write_nc;
  wire ex_mem_reg_write_nc;
  wire [1:0] ex_mem_result_src_nc;
  wire [2:0] ex_mem_funct3_nc;
  wire [31:0] ex_mem_rs2_nc;
  wire [4:0] ex_mem_rd_nc;

  rv32i_cpu #(
    .IMEM_SIZE (256),
    .DMEM_SIZE (256)
  ) u_rv32i_cpu (
    .clk_i (clk_w),
    .rst_i (rst_w),
    .imem_write_en_i (imem_write_en_w),
    .imem_write_addr_i (imem_write_addr_w),
    .imem_write_data_i (imem_write_data_w),
    .dmem_stall_i (1'b0),
    .dmem_rsp_valid_i (1'b0),
    .dmem_load_rd_i (5'b0),
    .dmem_rdata_i (32'b0),
    .ex_mem_alu_res_o (ex_mem_alu_res_nc),
    .ex_mem_mem_write_o (ex_mem_mem_write_nc),
    .ex_mem_reg_write_o (ex_mem_reg_write_nc),
    .ex_mem_result_src_o (ex_mem_result_src_nc),
    .ex_mem_funct3_o (ex_mem_funct3_nc),
    .ex_mem_rs2_o (ex_mem_rs2_nc),
    .ex_mem_rd_addr_o (ex_mem_rd_nc)
  );

  int test_count_r = 0;
  int pass_count_r = 0;

  initial clk_w = 0;
  always #5 clk_w = ~clk_w;

  initial begin
    if ($test$plusargs("vcd")) begin
      $dumpfile("sim/tb_rv32i_cpu.vcd");
      $dumpvars(0, tb_rv32i_cpu);
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

  task automatic check_mem (
    input string name,
    input int addr,
    input logic [7:0] expected
  );
    logic [7:0] actual;
    actual = u_rv32i_cpu.g_int_dmem.u_data_memory.mem_r[addr];
    test_count_r++;
    if (actual === expected) begin
      pass_count_r++;
    end else begin
      $display("FAIL: %s mem[%0d]=0x%02h expected=0x%02h", name, addr, actual, expected);
    end
  endtask

  task automatic load_smoke_program;
    // Load program via write port
    load_word(32'h00, 32'h00500093); // ADDI x1, x0, 5
    load_word(32'h04, 32'h00A00113); // ADDI x2, x0, 10
    load_word(32'h08, 32'h002081B3); // ADD x3, x1, x2
    load_word(32'h0C, 32'h40110233); // SUB x4, x2, x1
    load_word(32'h10, 32'h0020F2B3); // AND x5, x1, x2
    load_word(32'h14, 32'h0020E333); // OR x6, x1, x2
    load_word(32'h18, 32'h00302023); // SW x3, 0(x0)
    load_word(32'h1C, 32'h00002383); // LW x7, 0(x0)
    load_word(32'h20, 32'h00F00413); // ADDI x8, x0, 15
    load_word(32'h24, 32'h00838463); // BEQ x7, x8, +8
    load_word(32'h28, 32'h00100493); // ADDI x9, x0, 1 (skipped)
    load_word(32'h2C, 32'h00200513); // ADDI x10, x0, 2
  endtask

  task automatic verify_arch_state;
    // Verify register values
    check_reg("x0 hardwired", 0, 32'h0);
    check_reg("ADDI x1", 1, 32'h0000_0005);
    check_reg("ADDI x2", 2, 32'h0000_000A);
    check_reg("ADD x3", 3, 32'h0000_000F);
    check_reg("SUB x4", 4, 32'h0000_0005);
    check_reg("AND x5", 5, 32'h0000_0000);
    check_reg("OR x6", 6, 32'h0000_000F);
    check_reg("LW x7", 7, 32'h0000_000F);
    check_reg("ADDI x8", 8, 32'h0000_000F);
    check_reg("BEQ skip x9", 9, 32'h0000_0000); // skipped
    check_reg("ADDI x10", 10, 32'h0000_0002);

    // Verify data memory
    check_mem("mem[0]", 0, 8'h0F);
    check_mem("mem[1]", 1, 8'h00);
    check_mem("mem[2]", 2, 8'h00);
    check_mem("mem[3]", 3, 8'h00);

  endtask

  task automatic assert_invariants;
    if (u_rv32i_cpu.u_register_file.regs_r[0] !== 32'h0)
      $error("ASSERT: x0 must stay 0");
  endtask

  initial begin
    rst_w = 1'b1;
    imem_write_en_w = 1'b0;
    imem_write_addr_w = 32'b0;
    imem_write_data_w = 32'b0;
    @(posedge clk_w);
    #1;

    load_smoke_program();

    rst_w = 1'b0;

    begin : wait_for_fetch_pc
      int c;
      c = 0;
      while (u_rv32i_cpu.pc_r !== EXPECTED_FINAL_PC && c < MAX_WAIT_PC) begin
        @(posedge clk_w);
        c++;
      end
      if (c >= MAX_WAIT_PC) begin
        $fatal(1, "timeout: pc_r never reached 0x%08h (last seen 0x%08h)", EXPECTED_FINAL_PC,
            u_rv32i_cpu.pc_r);
      end
    end

    repeat (DRAIN_CYCLES) @(posedge clk_w);
    #1;

    verify_arch_state();
    assert_invariants();

    $display("PASSED: %0d", pass_count_r);
    $display("FAILED: %0d", test_count_r - pass_count_r);

    $finish;
  end

endmodule
