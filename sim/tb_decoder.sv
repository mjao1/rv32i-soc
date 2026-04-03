module tb_decoder import rv32i_pkg::*; ();
  logic [31:0] instruction_w;
  alu_op_t alu_op_w;
  logic alu_src_a_w;
  logic alu_src_b_w;
  logic reg_write_w;
  logic mem_write_w;
  result_src_t result_src_w;
  logic branch_w;
  branch_op_t branch_op_w;
  logic [4:0] rs1_addr_w;
  logic [4:0] rs2_addr_w;
  logic [4:0] rd_addr_w;
  logic [2:0] funct3_w;

  decoder u_decoder (
    .instruction_i (instruction_w),
    .alu_op_o (alu_op_w),
    .alu_src_a_o (alu_src_a_w),
    .alu_src_b_o (alu_src_b_w),
    .reg_write_o (reg_write_w),
    .mem_write_o (mem_write_w),
    .result_src_o (result_src_w),
    .branch_o (branch_w),
    .branch_op_o (branch_op_w),
    .rs1_addr_o (rs1_addr_w),
    .rs2_addr_o (rs2_addr_w),
    .rd_addr_o (rd_addr_w),
    .funct3_o (funct3_w)
  );

  int test_count_r = 0;
  int pass_count_r = 0;

  task automatic check(
    input string name,
    input logic [31:0] instr,
    input alu_op_t exp_alu_op,
    input logic exp_src_a,
    input logic exp_src_b,
    input logic exp_reg_wr,
    input logic exp_mem_wr,
    input result_src_t exp_result,
    input logic exp_branch,
    input branch_op_t exp_br_op
  );
    instruction_w = instr;
    #1;

    test_count_r++;
    if (alu_op_w === exp_alu_op &&
        alu_src_a_w === exp_src_a &&
        alu_src_b_w === exp_src_b &&
        reg_write_w === exp_reg_wr &&
        mem_write_w === exp_mem_wr &&
        result_src_w === exp_result &&
        branch_w === exp_branch &&
        branch_op_w === exp_br_op) begin
      pass_count_r++;
    end else begin
      $display("FAIL: %s", name);
      $display("alu_op: got=%0d exp=%0d", alu_op_w, exp_alu_op);
      $display("src_a: got=%0b exp=%0b", alu_src_a_w, exp_src_a);
      $display("src_b: got=%0b exp=%0b", alu_src_b_w, exp_src_b);
      $display("reg_wr: got=%0b exp=%0b", reg_write_w, exp_reg_wr);
      $display("mem_wr: got=%0b exp=%0b", mem_write_w, exp_mem_wr);
      $display("result: got=%0d exp=%0d", result_src_w, exp_result);
      $display("branch: got=%0b exp=%0b", branch_w, exp_branch);
      $display("br_op: got=%0d exp=%0d", branch_op_w, exp_br_op);
    end
  endtask

  initial begin
    // name instruction alu_op srcA srcB regW memW result br brOp

    // R-type
    // ADD x3, x1, x2: funct7=0000000, rs2=00010, rs1=00001, f3=000, rd=00011, op=0110011
    check("ADD", 32'b0000000_00010_00001_000_00011_0110011, ALU_ADD, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SUB x3, x1, x2
    check("SUB", 32'b0100000_00010_00001_000_00011_0110011, ALU_SUB, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SLL x3, x1, x2
    check("SLL", 32'b0000000_00010_00001_001_00011_0110011, ALU_SLL, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SLT x3, x1, x2
    check("SLT", 32'b0000000_00010_00001_010_00011_0110011, ALU_SLT, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SLTU x3, x1, x2
    check("SLTU", 32'b0000000_00010_00001_011_00011_0110011, ALU_SLTU, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // XOR x3, x1, x2
    check("XOR", 32'b0000000_00010_00001_100_00011_0110011, ALU_XOR, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SRL x3, x1, x2
    check("SRL", 32'b0000000_00010_00001_101_00011_0110011, ALU_SRL, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SRA x3, x1, x2
    check("SRA", 32'b0100000_00010_00001_101_00011_0110011, ALU_SRA, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // OR x3, x1, x2
    check("OR", 32'b0000000_00010_00001_110_00011_0110011, ALU_OR, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // AND x3, x1, x2
    check("AND", 32'b0000000_00010_00001_111_00011_0110011, ALU_AND, 0, 0, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);

    // I-type arithmetic
    // ADDI x1, x0, 5
    check("ADDI", 32'b0000_0000_0101_00000_000_00001_0010011, ALU_ADD, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SLTI x1, x2, 5
    check("SLTI", 32'b0000_0000_0101_00010_010_00001_0010011, ALU_SLT, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SLTIU x1, x2, 5
    check("SLTIU", 32'b0000_0000_0101_00010_011_00001_0010011, ALU_SLTU, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // XORI x1, x2, 5
    check("XORI", 32'b0000_0000_0101_00010_100_00001_0010011, ALU_XOR, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // ORI x1, x2, 5
    check("ORI", 32'b0000_0000_0101_00010_110_00001_0010011, ALU_OR, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // ANDI x1, x2, 5
    check("ANDI", 32'b0000_0000_0101_00010_111_00001_0010011, ALU_AND, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SLLI x1, x2, 3
    check("SLLI", 32'b0000000_00011_00010_001_00001_0010011, ALU_SLL, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SRLI x1, x2, 3
    check("SRLI", 32'b0000000_00011_00010_101_00001_0010011, ALU_SRL, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // SRAI x1, x2, 3
    check("SRAI", 32'b0100000_00011_00010_101_00001_0010011, ALU_SRA, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);

    // I-type loads
    // LW x1, 4(x2)
    check("LW", 32'b0000_0000_0100_00010_010_00001_0000011, ALU_ADD, 0, 1, 1, 0, RESULT_MEM, 0, BRANCH_BEQ);
    // LB x1, 0(x2)
    check("LB", 32'b0000_0000_0000_00010_000_00001_0000011, ALU_ADD, 0, 1, 1, 0, RESULT_MEM, 0, BRANCH_BEQ);

    // S-type stores
    // SW x1, 8(x2)
    check("SW", 32'b0000000_00001_00010_010_01000_0100011, ALU_ADD, 0, 1, 0, 1, RESULT_ALU, 0, BRANCH_BEQ);
    // SB x1, 0(x2)
    check("SB", 32'b0000000_00001_00010_000_00000_0100011, ALU_ADD, 0, 1, 0, 1, RESULT_ALU, 0, BRANCH_BEQ);

    // B-type branches
    // BEQ x1, x2, +8
    check("BEQ", 32'b0_000000_00010_00001_000_0100_0_1100011, ALU_ADD, 1, 1, 0, 0, RESULT_ALU, 1, BRANCH_BEQ);
    // BNE x1, x2, +8
    check("BNE", 32'b0_000000_00010_00001_001_0100_0_1100011, ALU_ADD, 1, 1, 0, 0, RESULT_ALU, 1, BRANCH_BNE);
    // BLT x1, x2, +8
    check("BLT", 32'b0_000000_00010_00001_100_0100_0_1100011, ALU_ADD, 1, 1, 0, 0, RESULT_ALU, 1, BRANCH_BLT);
    // BGE x1, x2, +8
    check("BGE", 32'b0_000000_00010_00001_101_0100_0_1100011, ALU_ADD, 1, 1, 0, 0, RESULT_ALU, 1, BRANCH_BGE);
    // BLTU x1, x2, +8
    check("BLTU", 32'b0_000000_00010_00001_110_0100_0_1100011, ALU_ADD, 1, 1, 0, 0, RESULT_ALU, 1, BRANCH_BLTU);
    // BGEU x1, x2, +8
    check("BGEU", 32'b0_000000_00010_00001_111_0100_0_1100011, ALU_ADD, 1, 1, 0, 0, RESULT_ALU, 1, BRANCH_BGEU);

    // U-type
    // LUI x1, 0x12345
    check("LUI", 32'h12345_0B7, ALU_ADD, 0, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);
    // AUIPC x1, 0x12345
    check("AUIPC", 32'h12345_097, ALU_ADD, 1, 1, 1, 0, RESULT_ALU, 0, BRANCH_BEQ);

    // J-type
    // JAL x1, +8
    check("JAL", 32'b0_0000000100_0_00000000_00001_1101111, ALU_ADD, 1, 1, 1, 0, RESULT_PC4, 1, BRANCH_JAL);
    // JALR x1, x2, 8
    check("JALR", 32'b0000_0000_1000_00010_000_00001_1100111, ALU_ADD, 0, 1, 1, 0, RESULT_PC4, 1, BRANCH_JAL);

    // Register address extraction
    // ADD x3, x1, x2 - verify rs1=1, rs2=2, rd=3
    instruction_w = 32'b0000000_00010_00001_000_00011_0110011;
    #1;
    test_count_r++;
    if (rs1_addr_w === 5'd1 && rs2_addr_w === 5'd2 && rd_addr_w === 5'd3) begin
      pass_count_r++;
    end else begin
      $display("FAIL: REG ADDRS rs1=%0d(exp 1) rs2=%0d(exp 2) rd=%0d(exp 3)", rs1_addr_w, rs2_addr_w, rd_addr_w);
    end

    // funct3 extraction
    // LH x1, 0(x2) - funct3=001
    instruction_w = 32'b0000_0000_0000_00010_001_00001_0000011;
    #1;
    test_count_r++;
    if (funct3_w === 3'b001) begin
      pass_count_r++;
    end else begin
      $display("FAIL: FUNCT3 got=%0b exp=001", funct3_w);
    end

    $display("PASSED: %0d", pass_count_r);
    $display("FAILED: %0d", test_count_r - pass_count_r);

    $finish;
  end

endmodule
