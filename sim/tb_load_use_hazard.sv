module tb_load_use_hazard import rv32i_pkg::*; ();
  localparam logic [31:0] EXPECTED_FINAL_PC = 32'h0000_0058;
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
      $dumpfile("sim/tb_load_use_hazard.vcd");
      $dumpvars(0, tb_load_use_hazard);
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

  task automatic check_mem(
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

  task automatic load_hazard_program;
    // Setup: store known values to data memory
    load_word(32'h00, 32'h02A00093); // ADDI x1, x0, 42
    load_word(32'h04, 32'h00102023); // SW   x1, 0(x0)
    load_word(32'h08, 32'h00A00093); // ADDI x1, x0, 10
    load_word(32'h0C, 32'h00102223); // SW   x1, 4(x0)

    // Test 1: LW -> ALU use (rs1)
    load_word(32'h10, 32'h00002103); // LW   x2, 0(x0)
    load_word(32'h14, 32'h000101B3); // ADD  x3, x2, x0

    // Test 2: LW -> ALU use (both rs1 and rs2)
    load_word(32'h18, 32'h00402203); // LW   x4, 4(x0)
    load_word(32'h1C, 32'h004202B3); // ADD  x5, x4, x4

    // Test 3: LW -> SUB
    load_word(32'h20, 32'h00002303); // LW   x6, 0(x0)
    load_word(32'h24, 32'h401303B3); // SUB  x7, x6, x1

    // Test 4: LW -> SW (store loaded value)
    load_word(32'h28, 32'h00402403); // LW   x8, 4(x0)
    load_word(32'h2C, 32'h00802423); // SW   x8, 8(x0)

    // Test 5: LW -> BEQ (branch on loaded value)
    load_word(32'h30, 32'h02A00493); // ADDI x9, x0, 42
    load_word(32'h34, 32'h00002503); // LW   x10, 0(x0)
    load_word(32'h38, 32'h00950463); // BEQ  x10, x9, +8
    load_word(32'h3C, 32'h06300593); // ADDI x11, x0, 99 (skipped)
    load_word(32'h40, 32'h00700613); // ADDI x12, x0, 7

    // Test 6: LW -> LW (pointer chasing)
    load_word(32'h44, 32'h00400713); // ADDI x14, x0, 4
    load_word(32'h48, 32'h00000693); // ADDI x13, x0, 0
    load_word(32'h4C, 32'h00D02823); // SW   x13, 16(x0)
    load_word(32'h50, 32'h01002703); // LW   x14, 16(x0)
    load_word(32'h54, 32'h00072783); // LW   x15, 0(x14)
  endtask

  task automatic verify_results;
    // Setup
    check_reg("x1=10", 1, 32'h0000_000A);

    // Test 1: LW -> ADD
    check_reg("LW x2", 2, 32'h0000_002A);
    check_reg("ADD x3", 3, 32'h0000_002A);

    // Test 2: LW -> ADD (both operands)
    check_reg("LW x4", 4, 32'h0000_000A);
    check_reg("ADD x5", 5, 32'h0000_0014);

    // Test 3: LW -> SUB
    check_reg("LW x6", 6, 32'h0000_002A);
    check_reg("SUB x7", 7, 32'h0000_0020);

    // Test 4: LW -> SW
    check_reg("LW x8", 8, 32'h0000_000A);
    check_mem("mem[8]", 8, 8'h0A);
    check_mem("mem[9]", 9, 8'h00);
    check_mem("mem[10]", 10, 8'h00);
    check_mem("mem[11]", 11, 8'h00);

    // Test 5: LW -> BEQ
    check_reg("x9=42", 9, 32'h0000_002A);
    check_reg("LW x10", 10, 32'h0000_002A);
    check_reg("BEQ skip x11", 11, 32'h0000_0000);
    check_reg("x12=7", 12, 32'h0000_0007);

    // Test 6: LW -> LW (pointer chase)
    check_reg("x13=0", 13, 32'h0000_0000);
    check_reg("LW x14", 14, 32'h0000_0000);
    check_reg("LW x15", 15, 32'h0000_002A);
  endtask

  initial begin
    rst_w = 1'b1;
    imem_write_en_w = 1'b0;
    imem_write_addr_w = 32'b0;
    imem_write_data_w = 32'b0;
    @(posedge clk_w);
    #1;

    load_hazard_program();

    rst_w = 1'b0;

    begin : wait_for_pc
      int c;
      c = 0;
      while (u_rv32i_cpu.pc_r !== EXPECTED_FINAL_PC && c < MAX_WAIT_PC) begin
        @(posedge clk_w);
        c++;
      end
      if (c >= MAX_WAIT_PC) begin
        $fatal(1, "timeout: pc_r never reached 0x%08h (last seen 0x%08h)",
            EXPECTED_FINAL_PC, u_rv32i_cpu.pc_r);
      end
    end

    repeat (DRAIN_CYCLES) @(posedge clk_w);
    #1;

    verify_results();

    if (u_rv32i_cpu.u_register_file.regs_r[0] !== 32'h0)
      $error("ASSERT: x0 must stay 0");

    $display("PASSED: %0d", pass_count_r);
    $display("FAILED: %0d", test_count_r - pass_count_r);

    $finish;
  end

endmodule
