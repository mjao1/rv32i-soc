module tb_alu import rv32i_pkg::*; ();
  logic [31:0] operand_a_w;
  logic [31:0] operand_b_w;
  alu_op_t alu_op_w;
  logic [31:0] alu_result_w;

  alu u_alu (
    .operand_a_i (operand_a_w),
    .operand_b_i (operand_b_w),
    .alu_op_i (alu_op_w),
    .alu_result_o (alu_result_w)
  );

  int test_count_r = 0;
  int pass_count_r = 0;

  task automatic check(
    input string name,
    input logic [31:0] a,
    input logic [31:0] b,
    input alu_op_t op,
    input logic [31:0] expected
  );
    operand_a_w = a;
    operand_b_w = b;
    alu_op_w = op;
    #1;

    test_count_r++;
    if (alu_result_w === expected) begin
      pass_count_r++;
    end else begin
      $display("FAIL: %-10s a=0x%08h b=0x%08h op=%0d got=0x%08h expected=0x%08h", name, a, b, op, alu_result_w, expected);
    end
  endtask

  initial begin
    // Add
    check("ADD", 32'h0000_0001, 32'h0000_0002, ALU_ADD, 32'h0000_0003);
    check("ADD zero", 32'h0000_0000, 32'h0000_0000, ALU_ADD, 32'h0000_0000);
    check("ADD ovfl", 32'hFFFF_FFFF, 32'h0000_0001, ALU_ADD, 32'h0000_0000);
    check("ADD neg", 32'hFFFF_FFFE, 32'h0000_0003, ALU_ADD, 32'h0000_0001);

    // Subtract
    check("SUB", 32'h0000_0005, 32'h0000_0003, ALU_SUB, 32'h0000_0002);
    check("SUB neg", 32'h0000_0003, 32'h0000_0005, ALU_SUB, 32'hFFFF_FFFE);
    check("SUB zero", 32'h0000_0005, 32'h0000_0005, ALU_SUB, 32'h0000_0000);

    // AND
    check("AND", 32'hFF00_FF00, 32'h0F0F_0F0F, ALU_AND, 32'h0F00_0F00);
    check("AND zero", 32'hFFFF_FFFF, 32'h0000_0000, ALU_AND, 32'h0000_0000);
    check("AND ones", 32'hFFFF_FFFF, 32'hFFFF_FFFF, ALU_AND, 32'hFFFF_FFFF);

    // OR
    check("OR", 32'hFF00_FF00, 32'h0F0F_0F0F, ALU_OR,  32'hFF0F_FF0F);
    check("OR zero", 32'h0000_0000, 32'h0000_0000, ALU_OR,  32'h0000_0000);

    // XOR
    check("XOR", 32'hFF00_FF00, 32'h0F0F_0F0F, ALU_XOR, 32'hF00F_F00F);
    check("XOR same", 32'hAAAA_AAAA, 32'hAAAA_AAAA, ALU_XOR, 32'h0000_0000);
    check("XOR inv", 32'h0000_0000, 32'hFFFF_FFFF, ALU_XOR, 32'hFFFF_FFFF);

    // Set less than signed
    check("SLT true", 32'hFFFF_FFFF, 32'h0000_0001, ALU_SLT, 32'h0000_0001); // -1 < 1
    check("SLT false", 32'h0000_0001, 32'hFFFF_FFFF, ALU_SLT, 32'h0000_0000); // 1 !< -1
    check("SLT eq", 32'h0000_0005, 32'h0000_0005, ALU_SLT, 32'h0000_0000);
    check("SLT minmax", 32'h8000_0000, 32'h7FFF_FFFF, ALU_SLT, 32'h0000_0001); // INT_MIN < INT_MAX

    // Set less than unsigned
    check("SLTU true", 32'h0000_0001, 32'hFFFF_FFFF, ALU_SLTU, 32'h0000_0001);
    check("SLTU false", 32'hFFFF_FFFF, 32'h0000_0001, ALU_SLTU, 32'h0000_0000);
    check("SLTU eq", 32'h0000_0005, 32'h0000_0005, ALU_SLTU, 32'h0000_0000);

    // Shift left logical
    check("SLL", 32'h0000_0001, 32'h0000_0004, ALU_SLL, 32'h0000_0010);
    check("SLL max", 32'h0000_0001, 32'h0000_001F, ALU_SLL, 32'h8000_0000);
    check("SLL zero", 32'h0000_0001, 32'h0000_0000, ALU_SLL, 32'h0000_0001);
    check("SLL mask", 32'h0000_0001, 32'h0000_0020, ALU_SLL, 32'h0000_0001); // only [4:0] used

    // Shift right logical
    check("SRL", 32'h8000_0000, 32'h0000_0004, ALU_SRL, 32'h0800_0000);
    check("SRL max", 32'h8000_0000, 32'h0000_001F, ALU_SRL, 32'h0000_0001);
    check("SRL zero", 32'h8000_0000, 32'h0000_0000, ALU_SRL, 32'h8000_0000);

    // Shift right arithmetic
    check("SRA neg", 32'h8000_0000, 32'h0000_0004, ALU_SRA, 32'hF800_0000);
    check("SRA pos", 32'h7FFF_FFFF, 32'h0000_0004, ALU_SRA, 32'h07FF_FFFF);
    check("SRA max", 32'h8000_0000, 32'h0000_001F, ALU_SRA, 32'hFFFF_FFFF);
    check("SRA zero", 32'h8000_0000, 32'h0000_0000, ALU_SRA, 32'h8000_0000);

    $display("PASSED: %0d", pass_count_r);
    $display("FAILED: %0d", test_count_r - pass_count_r);
    
    $finish;
  end

endmodule
