module rv32i_cpu #(
  parameter IMEM_SIZE = 1024,
  parameter DMEM_SIZE = 4096,
  parameter logic [31:0] DMEM_BASE = 32'h0000_0000,
  parameter bit EXT_DMEM = 1'b0
) (
  input logic clk_i,
  input logic rst_i,
  input logic imem_write_en_i,
  input logic [31:0] imem_write_addr_i,
  input logic [31:0] imem_write_data_i,
  input logic dmem_stall_i,
  input logic dmem_rsp_valid_i,
  input logic [4:0] dmem_load_rd_i,
  input logic [31:0] dmem_rdata_i,

  output wire [31:0] ex_mem_alu_res_o,
  output wire ex_mem_mem_write_o,
  output wire ex_mem_reg_write_o,
  output wire [1:0] ex_mem_result_src_o,
  output wire [2:0] ex_mem_funct3_o,
  output wire [31:0] ex_mem_rs2_o,
  output wire [4:0] ex_mem_rd_addr_o
);

  localparam logic [31:0] NOP_INSTR = 32'h0000_0013; // ADDI x0, x0, 0

  // PC
  logic [31:0] pc_r;
  logic [31:0] pc_plus4_w;

  assign pc_plus4_w = pc_r + 32'd4;

  logic stall_w;
  wire stall_mem_eff_w = EXT_DMEM && dmem_stall_i;
  wire stall_any_w = stall_w || stall_mem_eff_w;

  logic [31:0] redirect_target_w;

  always_ff @(posedge clk_i) begin
    if (rst_i)
      pc_r <= 32'b0;
    else if (ex_flush_w)
      pc_r <= redirect_target_w;
    else if (stall_any_w)
      pc_r <= pc_r;
    else if (predict_taken_if_w)
      pc_r <= predicted_target_if_w;
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

  // Branch predictor (BTFNT)
  logic predict_taken_if_w;
  logic [31:0] predicted_target_if_w;

  branch_predictor u_branch_predictor (
    .instruction_i (instruction_f_w),
    .pc_i (pc_r),
    .predict_taken_o (predict_taken_if_w),
    .predicted_target_o (predicted_target_if_w)
  );

  // -IF/ID-
  logic [31:0] if_id_pc_r;
  logic [31:0] if_id_instr_r;
  logic if_id_predicted_taken_r;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      if_id_pc_r    <= 32'b0;
      if_id_instr_r <= NOP_INSTR;
      if_id_predicted_taken_r <= 1'b0;
    end else if (ex_flush_w) begin
      if_id_instr_r <= NOP_INSTR;
      if_id_pc_r    <= 32'b0;
      if_id_predicted_taken_r <= 1'b0;
    end else if (stall_any_w) begin
      // hold
    end else begin
      if_id_instr_r <= instruction_f_w;
      if_id_pc_r    <= pc_r;
      if_id_predicted_taken_r <= predict_taken_if_w;
    end
  end

  // -ID-
  logic [3:0] id_alu_op_w;
  logic id_alu_src_a_w;
  logic id_alu_src_b_w;
  logic id_reg_write_w;
  logic id_mem_write_w;
  logic [1:0] id_result_src_w;
  logic id_branch_w;
  logic [2:0] id_branch_op_w;
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

  logic [31:0] ex_rs1_rf_data_w;
  logic [31:0] ex_rs2_rf_data_w;

  register_file u_register_file (
    .clk_i (clk_i),
    .rst_i (rst_i),
    .rs1_addr_i (id_rs1_addr_w),
    .rs2_addr_i (id_rs2_addr_w),
    .rd_addr_i (wb_rd_addr_w),
    .rd_data_i (wb_rd_data_w),
    .reg_write_i (wb_reg_write_w),
    .rs1_data_o (id_rs1_data_w),
    .rs2_data_o (id_rs2_data_w),
    .ex_rs1_addr_i (id_ex_rs1_addr_r),
    .ex_rs2_addr_i (id_ex_rs2_addr_r),
    .ex_rs1_data_o (ex_rs1_rf_data_w),
    .ex_rs2_data_o (ex_rs2_rf_data_w)
  );

  // -ID/EX-
  logic [31:0] id_ex_pc_r;
  logic [31:0] id_ex_imm_r;
  logic [31:0] id_ex_rs1_data_r;
  logic [31:0] id_ex_rs2_data_r;
  logic [3:0] id_ex_alu_op_r;
  logic id_ex_alu_src_a_r;
  logic id_ex_alu_src_b_r;
  logic id_ex_reg_write_r;
  logic id_ex_mem_write_r;
  logic [1:0] id_ex_result_src_r;
  logic id_ex_branch_r;
  logic [2:0] id_ex_branch_op_r;
  logic [4:0] id_ex_rs1_addr_r;
  logic [4:0] id_ex_rs2_addr_r;
  logic [4:0] id_ex_rd_addr_r;
  logic [2:0] id_ex_funct3_r;
  logic id_ex_predicted_taken_r;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      id_ex_pc_r         <= 32'b0;
      id_ex_imm_r        <= 32'b0;
      id_ex_rs1_data_r   <= 32'b0;
      id_ex_rs2_data_r   <= 32'b0;
      id_ex_alu_op_r     <= rv32i_pkg::ALU_ADD;
      id_ex_alu_src_a_r  <= 1'b0;
      id_ex_alu_src_b_r  <= 1'b0;
      id_ex_reg_write_r  <= 1'b0;
      id_ex_mem_write_r  <= 1'b0;
      id_ex_result_src_r <= rv32i_pkg::RESULT_ALU;
      id_ex_branch_r     <= 1'b0;
      id_ex_branch_op_r  <= rv32i_pkg::BRANCH_BEQ;
      id_ex_rs1_addr_r   <= 5'b0;
      id_ex_rs2_addr_r   <= 5'b0;
      id_ex_rd_addr_r    <= 5'b0;
      id_ex_funct3_r     <= 3'b0;
      id_ex_predicted_taken_r <= 1'b0;
    end else if (ex_flush_w) begin
      id_ex_pc_r         <= 32'b0;
      id_ex_imm_r        <= 32'b0;
      id_ex_rs1_data_r   <= 32'b0;
      id_ex_rs2_data_r   <= 32'b0;
      id_ex_alu_op_r     <= rv32i_pkg::ALU_ADD;
      id_ex_alu_src_a_r  <= 1'b0;
      id_ex_alu_src_b_r  <= 1'b0;
      id_ex_reg_write_r  <= 1'b0;
      id_ex_mem_write_r  <= 1'b0;
      id_ex_result_src_r <= rv32i_pkg::RESULT_ALU;
      id_ex_branch_r     <= 1'b0;
      id_ex_branch_op_r  <= rv32i_pkg::BRANCH_BEQ;
      id_ex_rs1_addr_r   <= 5'b0;
      id_ex_rs2_addr_r   <= 5'b0;
      id_ex_rd_addr_r    <= 5'b0;
      id_ex_funct3_r     <= 3'b0;
      id_ex_predicted_taken_r <= 1'b0;
    end else if (stall_mem_eff_w) begin
      id_ex_pc_r         <= id_ex_pc_r;
      id_ex_imm_r        <= id_ex_imm_r;
      id_ex_rs1_data_r   <= id_ex_rs1_data_r;
      id_ex_rs2_data_r   <= id_ex_rs2_data_r;
      id_ex_alu_op_r     <= id_ex_alu_op_r;
      id_ex_alu_src_a_r  <= id_ex_alu_src_a_r;
      id_ex_alu_src_b_r  <= id_ex_alu_src_b_r;
      id_ex_reg_write_r  <= id_ex_reg_write_r;
      id_ex_mem_write_r  <= id_ex_mem_write_r;
      id_ex_result_src_r <= id_ex_result_src_r;
      id_ex_branch_r     <= id_ex_branch_r;
      id_ex_branch_op_r  <= id_ex_branch_op_r;
      id_ex_rs1_addr_r   <= id_ex_rs1_addr_r;
      id_ex_rs2_addr_r   <= id_ex_rs2_addr_r;
      id_ex_rd_addr_r    <= id_ex_rd_addr_r;
      id_ex_funct3_r     <= id_ex_funct3_r;
      id_ex_predicted_taken_r <= id_ex_predicted_taken_r;
    end else if (stall_w) begin
      id_ex_pc_r         <= 32'b0;
      id_ex_imm_r        <= 32'b0;
      id_ex_rs1_data_r   <= 32'b0;
      id_ex_rs2_data_r   <= 32'b0;
      id_ex_alu_op_r     <= rv32i_pkg::ALU_ADD;
      id_ex_alu_src_a_r  <= 1'b0;
      id_ex_alu_src_b_r  <= 1'b0;
      id_ex_reg_write_r  <= 1'b0;
      id_ex_mem_write_r  <= 1'b0;
      id_ex_result_src_r <= rv32i_pkg::RESULT_ALU;
      id_ex_branch_r     <= 1'b0;
      id_ex_branch_op_r  <= rv32i_pkg::BRANCH_BEQ;
      id_ex_rs1_addr_r   <= 5'b0;
      id_ex_rs2_addr_r   <= 5'b0;
      id_ex_rd_addr_r    <= 5'b0;
      id_ex_funct3_r     <= 3'b0;
      id_ex_predicted_taken_r <= 1'b0;
    end else begin
      id_ex_pc_r         <= if_id_pc_r;
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
      id_ex_predicted_taken_r <= if_id_predicted_taken_r;
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
  logic ex_flush_w;
  branch_unit u_branch_unit (
    .rs1_data_i (ex_rs1_fwd_w),
    .rs2_data_i (ex_rs2_fwd_w),
    .branch_op_i (id_ex_branch_op_r),
    .branch_i (id_ex_branch_r),
    .predicted_taken_i (id_ex_predicted_taken_r),
    .branch_taken_o (ex_branch_taken_w),
    .flush_o (ex_flush_w)
  );

  // Forward unit
  logic [31:0] ex_rs1_fwd_w;
  logic [31:0] ex_rs2_fwd_w;

  forward_unit u_forward_unit (
    .id_ex_rs1_addr_i (id_ex_rs1_addr_r),
    .id_ex_rs2_addr_i (id_ex_rs2_addr_r),
    .id_ex_rs1_data_i (ex_rs1_rf_data_w),
    .id_ex_rs2_data_i (ex_rs2_rf_data_w),
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

  assign redirect_target_w = (id_ex_predicted_taken_r && !ex_branch_taken_w) ? (id_ex_pc_r + 32'd4) : {ex_alu_result_w[31:1], 1'b0};

  // Hazard unit
  hazard_unit u_hazard_unit (
    .if_id_rs1_i (id_rs1_addr_w),
    .if_id_rs2_i (id_rs2_addr_w),
    .id_ex_reg_write_i (id_ex_reg_write_r),
    .id_ex_result_src_i (id_ex_result_src_r),
    .id_ex_rd_i (id_ex_rd_addr_r),
    .stall_if_o (stall_w)
  );

  // -EX/MEM-
  logic [31:0] ex_mem_alu_res_r;
  logic [31:0] ex_mem_rs2_r;
  logic ex_mem_mem_write_r;
  logic [2:0] ex_mem_funct3_r;
  logic ex_mem_reg_write_r;
  logic [1:0] ex_mem_result_src_r;
  logic [4:0] ex_mem_rd_addr_r;
  logic [31:0] ex_mem_pc_plus4_r;

  // -MEM-
  logic [31:0] mem_read_data_w;
  logic [31:0] mem_read_data_int_w;

  // When EXT_DMEM = 1, LSU drives loads via dmem_rdata_i
  generate
    if (!EXT_DMEM) begin : g_int_dmem
      data_memory #(
        .MEM_SIZE (DMEM_SIZE),
        .DMEM_BASE (DMEM_BASE)
      ) u_data_memory (
        .clk_i (clk_i),
        .addr_i (ex_mem_alu_res_r),
        .write_data_i (ex_mem_rs2_r),
        .mem_write_i (ex_mem_mem_write_r),
        .funct3_i (ex_mem_funct3_r),
        .read_data_o (mem_read_data_int_w)
      );
    end else begin : g_no_int_dmem
      assign mem_read_data_int_w = 32'b0;
    end
  endgenerate

  assign mem_read_data_w = EXT_DMEM ? dmem_rdata_i : mem_read_data_int_w;

  assign ex_mem_alu_res_o = ex_mem_alu_res_r;
  assign ex_mem_mem_write_o = ex_mem_mem_write_r;
  assign ex_mem_reg_write_o = ex_mem_reg_write_r;
  assign ex_mem_result_src_o = ex_mem_result_src_r;
  assign ex_mem_funct3_o = ex_mem_funct3_r;
  assign ex_mem_rs2_o = ex_mem_rs2_r;
  assign ex_mem_rd_addr_o = ex_mem_rd_addr_r;

  // Result mux to register file write data
  logic [31:0] ex_mem_wb_data_w;

  always_comb begin
    case (ex_mem_result_src_r)
      rv32i_pkg::RESULT_ALU: ex_mem_wb_data_w = ex_mem_alu_res_r;
      rv32i_pkg::RESULT_PC4: ex_mem_wb_data_w = ex_mem_pc_plus4_r;
      rv32i_pkg::RESULT_MEM: ex_mem_wb_data_w = mem_read_data_w;
      default: ex_mem_wb_data_w = ex_mem_alu_res_r;
    endcase
  end

  // -MEM/WB-
  logic [31:0] mem_wb_wb_data_r;
  logic mem_wb_reg_write_r;
  logic [4:0] mem_wb_rd_addr_r;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      ex_mem_alu_res_r    <= 32'b0;
      ex_mem_rs2_r        <= 32'b0;
      ex_mem_mem_write_r  <= 1'b0;
      ex_mem_funct3_r     <= 3'b0;
      ex_mem_reg_write_r  <= 1'b0;
      ex_mem_result_src_r <= rv32i_pkg::RESULT_ALU;
      ex_mem_rd_addr_r    <= 5'b0;
      ex_mem_pc_plus4_r   <= 32'b0;
    end else if (stall_mem_eff_w) begin
      ex_mem_alu_res_r    <= ex_mem_alu_res_r;
      ex_mem_rs2_r        <= ex_mem_rs2_r;
      ex_mem_mem_write_r  <= ex_mem_mem_write_r;
      ex_mem_funct3_r     <= ex_mem_funct3_r;
      ex_mem_reg_write_r  <= ex_mem_reg_write_r;
      ex_mem_result_src_r <= ex_mem_result_src_r;
      ex_mem_rd_addr_r    <= ex_mem_rd_addr_r;
      ex_mem_pc_plus4_r   <= ex_mem_pc_plus4_r;
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

  // EXT_DMEM: LSU pulses rsp in ST_RESP; use latched rd (dmem_load_rd_i) — ex_mem may already be the next insn.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mem_wb_wb_data_r   <= 32'b0;
      mem_wb_reg_write_r <= 1'b0;
      mem_wb_rd_addr_r   <= 5'b0;
    end else if (EXT_DMEM && dmem_rsp_valid_i) begin
      mem_wb_wb_data_r   <= dmem_rdata_i;
      mem_wb_reg_write_r <= 1'b1;
      mem_wb_rd_addr_r   <= dmem_load_rd_i;
    end else if (!stall_mem_eff_w) begin
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
