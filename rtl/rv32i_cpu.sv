module rv32i_cpu import rv32i_pkg::*; #(
  parameter IMEM_SIZE = 1024,
  parameter DMEM_SIZE = 4096,
  parameter logic [31:0] DMEM_BASE = 32'h0000_0000
) (
  input logic clk_i,
  input logic rst_i,
  input logic imem_write_en_i,
  input logic [31:0] imem_write_addr_i,
  input logic [31:0] imem_write_data_i
);

  localparam logic [31:0] NOP_INSTR = 32'h0000_0013; // ADDI x0, x0, 0

  // PC
  logic [31:0] pc_r;
  logic [31:0] pc_plus4_w;

  assign pc_plus4_w = pc_r + 32'd4;

  logic stall_w;
  logic branch_taken_ex_w;
  logic [31:0] branch_target_ex_w;

  always_ff @(posedge clk_i) begin
    if (rst_i)
      pc_r <= 32'b0;
    else if (stall_w)
      pc_r <= pc_r;
    else if (branch_taken_ex_w)
      pc_r <= branch_target_ex_w;
    else
      pc_r <= pc_plus4_w;
  end

  // -IF-
  logic [31:0] instruction_f_w;

  // Instruction memory
  instruction_memory #(
    .MEM_SIZE (IMEM_SIZE)
  ) u_instruction_memory (
    .clk_i (clk_i),
    .write_en_i (imem_write_en_i),
    .write_addr_i (imem_write_addr_i),
    .write_data_i (imem_write_data_i),
    .addr_i (pc_r),
    .instruction_o (instruction_f_w)
  );

  // -IF/ID-
  logic [31:0] if_id_pc_r;
  logic [31:0] if_id_instr_r;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      if_id_pc_r    <= 32'b0;
      if_id_instr_r <= NOP_INSTR;
    end else if (branch_taken_ex_w) begin
      if_id_instr_r <= NOP_INSTR;
      if_id_pc_r    <= 32'b0;
    end else if (stall_w) begin
      // hold
    end else begin
      if_id_instr_r <= instruction_f_w;
      if_id_pc_r    <= pc_r;
    end
  end

  // -ID-
  alu_op_t id_alu_op_w;
  logic id_alu_src_a_w;
  logic id_alu_src_b_w;
  logic id_reg_write_w;
  logic id_mem_write_w;
  result_src_t id_result_src_w;
  logic id_branch_w;
  branch_op_t id_branch_op_w;
  logic [4:0] id_rs1_addr_w;
  logic [4:0] id_rs2_addr_w;
  logic [4:0] id_rd_addr_w;
  logic [2:0] id_funct3_w;

  // Decoder
  decoder u_decoder (
    .instruction_i (if_id_instr_r),
    .alu_op_o (id_alu_op_w),
    .alu_src_a_o (id_alu_src_a_w),
    .alu_src_b_o (id_alu_src_b_w),
    .reg_write_o (id_reg_write_w),
    .mem_write_o (id_mem_write_w),
    .result_src_o (id_result_src_w),
    .branch_o (id_branch_w),
    .branch_op_o (id_branch_op_w),
    .rs1_addr_o (id_rs1_addr_w),
    .rs2_addr_o (id_rs2_addr_w),
    .rd_addr_o (id_rd_addr_w),
    .funct3_o (id_funct3_w)
  );

  // Immediate generator
  logic [31:0] id_immediate_w;

  immediate_generator u_immediate_generator (
    .instruction_i (if_id_instr_r),
    .immediate_o (id_immediate_w)
  );

  // Register file
  logic [31:0] id_rs1_data_w;
  logic [31:0] id_rs2_data_w;
  logic [31:0] wb_rd_data_w;
  logic wb_reg_write_w;
  logic [4:0] wb_rd_addr_w;

  register_file u_register_file (
    .clk_i (clk_i),
    .rst_i (rst_i),
    .rs1_addr_i (id_rs1_addr_w),
    .rs2_addr_i (id_rs2_addr_w),
    .rd_addr_i (wb_rd_addr_w),
    .rd_data_i (wb_rd_data_w),
    .reg_write_i (wb_reg_write_w),
    .rs1_data_o (id_rs1_data_w),
    .rs2_data_o (id_rs2_data_w)
  );

  // -ID/EX-
  logic [31:0] id_ex_pc_r;
  logic [31:0] id_ex_instr_r;
  logic [31:0] id_ex_imm_r;
  logic [31:0] id_ex_rs1_data_r;
  logic [31:0] id_ex_rs2_data_r;
  alu_op_t id_ex_alu_op_r;
  logic id_ex_alu_src_a_r;
  logic id_ex_alu_src_b_r;
  logic id_ex_reg_write_r;
  logic id_ex_mem_write_r;
  result_src_t id_ex_result_src_r;
  logic id_ex_branch_r;
  branch_op_t id_ex_branch_op_r;
  logic [4:0] id_ex_rs1_addr_r;
  logic [4:0] id_ex_rs2_addr_r;
  logic [4:0] id_ex_rd_addr_r;
  logic [2:0] id_ex_funct3_r;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      id_ex_pc_r         <= 32'b0;
      id_ex_instr_r      <= NOP_INSTR;
      id_ex_imm_r        <= 32'b0;
      id_ex_rs1_data_r   <= 32'b0;
      id_ex_rs2_data_r   <= 32'b0;
      id_ex_alu_op_r     <= ALU_ADD;
      id_ex_alu_src_a_r  <= 1'b0;
      id_ex_alu_src_b_r  <= 1'b0;
      id_ex_reg_write_r  <= 1'b0;
      id_ex_mem_write_r  <= 1'b0;
      id_ex_result_src_r <= RESULT_ALU;
      id_ex_branch_r     <= 1'b0;
      id_ex_branch_op_r  <= BRANCH_BEQ;
      id_ex_rs1_addr_r   <= 5'b0;
      id_ex_rs2_addr_r   <= 5'b0;
      id_ex_rd_addr_r    <= 5'b0;
      id_ex_funct3_r     <= 3'b0;
    end else if (branch_taken_ex_w || stall_w) begin
      id_ex_pc_r         <= 32'b0;
      id_ex_instr_r      <= NOP_INSTR;
      id_ex_imm_r        <= 32'b0;
      id_ex_rs1_data_r   <= 32'b0;
      id_ex_rs2_data_r   <= 32'b0;
      id_ex_alu_op_r     <= ALU_ADD;
      id_ex_alu_src_a_r  <= 1'b0;
      id_ex_alu_src_b_r  <= 1'b0;
      id_ex_reg_write_r  <= 1'b0;
      id_ex_mem_write_r  <= 1'b0;
      id_ex_result_src_r <= RESULT_ALU;
      id_ex_branch_r     <= 1'b0;
      id_ex_branch_op_r  <= BRANCH_BEQ;
      id_ex_rs1_addr_r   <= 5'b0;
      id_ex_rs2_addr_r   <= 5'b0;
      id_ex_rd_addr_r    <= 5'b0;
      id_ex_funct3_r     <= 3'b0;
    end else begin
      id_ex_pc_r         <= if_id_pc_r;
      id_ex_instr_r      <= if_id_instr_r;
      id_ex_imm_r        <= id_immediate_w;
      id_ex_rs1_data_r   <= id_rs1_data_w;
      id_ex_rs2_data_r   <= id_rs2_data_w;
      id_ex_alu_op_r     <= id_alu_op_w;
      id_ex_alu_src_a_r  <= id_alu_src_a_w;
      id_ex_alu_src_b_r  <= id_alu_src_b_w;
      id_ex_reg_write_r  <= id_reg_write_w;
      id_ex_mem_write_r  <= id_mem_write_w;
      id_ex_result_src_r <= id_result_src_w;
      id_ex_branch_r     <= id_branch_w;
      id_ex_branch_op_r  <= id_branch_op_w;
      id_ex_rs1_addr_r   <= id_rs1_addr_w;
      id_ex_rs2_addr_r   <= id_rs2_addr_w;
      id_ex_rd_addr_r    <= id_rd_addr_w;
      id_ex_funct3_r     <= id_funct3_w;
    end
  end

  // -EX-
  logic [31:0] ex_alu_a_w;
  logic [31:0] ex_alu_b_w;
  assign ex_alu_a_w = id_ex_alu_src_a_r ? id_ex_pc_r : ex_rs1_fwd_w;
  assign ex_alu_b_w = id_ex_alu_src_b_r ? id_ex_imm_r : ex_rs2_fwd_w;

  // ALU
  logic [31:0] ex_alu_result_w;
  alu u_alu (
    .operand_a_i (ex_alu_a_w),
    .operand_b_i (ex_alu_b_w),
    .alu_op_i (id_ex_alu_op_r),
    .alu_result_o (ex_alu_result_w)
  );

  // Branch unit
  logic ex_branch_taken_w;
  branch_unit u_branch_unit (
    .rs1_data_i (ex_rs1_fwd_w),
    .rs2_data_i (ex_rs2_fwd_w),
    .branch_op_i (id_ex_branch_op_r),
    .branch_i (id_ex_branch_r),
    .branch_taken_o (ex_branch_taken_w)
  );

  // Forward unit
  logic [31:0] ex_rs1_fwd_w;
  logic [31:0] ex_rs2_fwd_w;

  forward_unit u_forward_unit (
    .id_ex_rs1_addr_i (id_ex_rs1_addr_r),
    .id_ex_rs2_addr_i (id_ex_rs2_addr_r),
    .id_ex_rs1_data_i (id_ex_rs1_data_r),
    .id_ex_rs2_data_i (id_ex_rs2_data_r),
    .ex_mem_reg_write_i (ex_mem_reg_write_r),
    .ex_mem_rd_i (ex_mem_rd_addr_r),
    .ex_mem_result_src_i (ex_mem_result_src_r),
    .ex_mem_alu_res_i (ex_mem_alu_res_r),
    .mem_wb_reg_write_i (mem_wb_reg_write_r),
    .mem_wb_rd_i (mem_wb_rd_addr_r),
    .mem_wb_data_i (mem_wb_wb_data_r),
    .rs1_fwd_o (ex_rs1_fwd_w),
    .rs2_fwd_o (ex_rs2_fwd_w)
  );

  assign branch_taken_ex_w = ex_branch_taken_w;
  assign branch_target_ex_w = {ex_alu_result_w[31:1], 1'b0};

  // Hazard unit
  hazard_unit u_hazard_unit (
    .id_ex_opcode_i (id_ex_instr_r[6:0]),
    .id_ex_rs1_i (id_ex_rs1_addr_r),
    .id_ex_rs2_i (id_ex_rs2_addr_r),
    .ex_mem_reg_write_i (ex_mem_reg_write_r),
    .ex_mem_result_src_i (ex_mem_result_src_r),
    .ex_mem_rd_i (ex_mem_rd_addr_r),
    .stall_if_o (stall_w)
  );

  // -EX/MEM-
  logic [31:0] ex_mem_alu_res_r;
  logic [31:0] ex_mem_rs2_r;
  logic ex_mem_mem_write_r;
  logic [2:0] ex_mem_funct3_r;
  logic ex_mem_reg_write_r;
  result_src_t ex_mem_result_src_r;
  logic [4:0] ex_mem_rd_addr_r;
  logic [31:0] ex_mem_pc_plus4_r;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      ex_mem_alu_res_r    <= 32'b0;
      ex_mem_rs2_r        <= 32'b0;
      ex_mem_mem_write_r  <= 1'b0;
      ex_mem_funct3_r     <= 3'b0;
      ex_mem_reg_write_r  <= 1'b0;
      ex_mem_result_src_r <= RESULT_ALU;
      ex_mem_rd_addr_r    <= 5'b0;
      ex_mem_pc_plus4_r   <= 32'b0;
    end else begin
      ex_mem_alu_res_r    <= ex_alu_result_w;
      ex_mem_rs2_r        <= ex_rs2_fwd_w;
      ex_mem_mem_write_r  <= id_ex_mem_write_r;
      ex_mem_funct3_r     <= id_ex_funct3_r;
      ex_mem_reg_write_r  <= id_ex_reg_write_r;
      ex_mem_result_src_r <= id_ex_result_src_r;
      ex_mem_rd_addr_r    <= id_ex_rd_addr_r;
      ex_mem_pc_plus4_r   <= id_ex_pc_r + 32'd4;
    end
  end

  // -MEM-
  logic [31:0] mem_read_data_w;

  // Data memory
  data_memory #(
    .MEM_SIZE (DMEM_SIZE),
    .DMEM_BASE (DMEM_BASE)
  ) u_data_memory (
    .clk_i (clk_i),
    .addr_i (ex_mem_alu_res_r),
    .write_data_i (ex_mem_rs2_r),
    .mem_write_i (ex_mem_mem_write_r),
    .funct3_i (ex_mem_funct3_r),
    .read_data_o (mem_read_data_w)
  );

  // Result mux to register file write data
  logic [31:0] ex_mem_wb_data_w;

  always_comb begin
    case (ex_mem_result_src_r)
      RESULT_ALU: ex_mem_wb_data_w = ex_mem_alu_res_r;
      RESULT_PC4: ex_mem_wb_data_w = ex_mem_pc_plus4_r;
      RESULT_MEM: ex_mem_wb_data_w = mem_read_data_w;
      default: ex_mem_wb_data_w = ex_mem_alu_res_r;
    endcase
  end

  // -MEM/WB-
  logic [31:0] mem_wb_wb_data_r;
  logic mem_wb_reg_write_r;
  logic [4:0] mem_wb_rd_addr_r;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mem_wb_wb_data_r   <= 32'b0;
      mem_wb_reg_write_r <= 1'b0;
      mem_wb_rd_addr_r   <= 5'b0;
    end else begin
      mem_wb_wb_data_r   <= ex_mem_wb_data_w;
      mem_wb_reg_write_r <= ex_mem_reg_write_r;
      mem_wb_rd_addr_r   <= ex_mem_rd_addr_r;
    end
  end

  // -WB-
  assign wb_reg_write_w = mem_wb_reg_write_r;
  assign wb_rd_addr_w = mem_wb_rd_addr_r;
  assign wb_rd_data_w = mem_wb_wb_data_r;

endmodule
