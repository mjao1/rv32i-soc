module decoder import rv32i_pkg::*; (
  input logic [31:0] instruction_i,
  output alu_op_t alu_op_o,
  output logic alu_src_a_o,
  output logic alu_src_b_o,
  output logic reg_write_o,
  output logic mem_write_o,
  output result_src_t result_src_o,
  output logic branch_o,
  output branch_op_t branch_op_o,
  output logic [4:0] rs1_addr_o,
  output logic [4:0] rs2_addr_o,
  output logic [4:0] rd_addr_o,
  output logic [2:0] funct3_o
);

  logic [6:0] opcode_w;
  logic [2:0] funct3_w;
  logic [6:0] funct7_w;

  assign opcode_w = instruction_i[6:0];
  assign funct3_w = instruction_i[14:12];
  assign funct7_w = instruction_i[31:25];

  assign rs1_addr_o = instruction_i[19:15];
  assign rs2_addr_o = instruction_i[24:20];
  assign rd_addr_o  = instruction_i[11:7];
  assign funct3_o   = funct3_w;

  always_comb begin
    alu_op_o     = ALU_ADD;
    alu_src_a_o  = 1'b0; // rs1
    alu_src_b_o  = 1'b0; // rs2
    reg_write_o  = 1'b0;
    mem_write_o  = 1'b0;
    result_src_o = RESULT_ALU;
    branch_o     = 1'b0;
    branch_op_o  = BRANCH_BEQ;

    case (opcode_w)
      // R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
      OP_ALU_R: begin
        reg_write_o = 1'b1;
        alu_src_b_o = 1'b0; // rs2
        case (funct3_w)
          3'b000: if (funct7_w[5]) alu_op_o = ALU_SUB; else alu_op_o = ALU_ADD;
          3'b001: alu_op_o = ALU_SLL;
          3'b010: alu_op_o = ALU_SLT;
          3'b011: alu_op_o = ALU_SLTU;
          3'b100: alu_op_o = ALU_XOR;
          3'b101: if (funct7_w[5]) alu_op_o = ALU_SRA; else alu_op_o = ALU_SRL;
          3'b110: alu_op_o = ALU_OR;
          3'b111: alu_op_o = ALU_AND;
        endcase
      end

      // I-type arithmetic: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
      OP_ALU_I: begin
        reg_write_o = 1'b1;
        alu_src_b_o = 1'b1; // immediate
        case (funct3_w)
          3'b000: alu_op_o = ALU_ADD;
          3'b001: alu_op_o = ALU_SLL;
          3'b010: alu_op_o = ALU_SLT;
          3'b011: alu_op_o = ALU_SLTU;
          3'b100: alu_op_o = ALU_XOR;
          3'b101: if (funct7_w[5]) alu_op_o = ALU_SRA; else alu_op_o = ALU_SRL;
          3'b110: alu_op_o = ALU_OR;
          3'b111: alu_op_o = ALU_AND;
        endcase
      end

      // I-type loads: LB, LH, LW, LBU, LHU
      OP_LOAD: begin
        reg_write_o  = 1'b1;
        alu_src_b_o  = 1'b1; // immediate (offset)
        alu_op_o     = ALU_ADD;
        result_src_o = RESULT_MEM;
      end

      // S-type stores: SB, SH, SW
      OP_STORE: begin
        mem_write_o = 1'b1;
        alu_src_b_o = 1'b1; // immediate (offset)
        alu_op_o    = ALU_ADD;
      end


      // B-type branches: BEQ, BNE, BLT, BGE, BLTU, BGEU
      OP_BRANCH: begin
        branch_o    = 1'b1;
        branch_op_o = branch_op_t'(funct3_w);
        alu_src_a_o = 1'b1; // PC
        alu_src_b_o = 1'b1; // immediate (offset)
        alu_op_o    = ALU_ADD;
      end

      // U-type: LUI
      OP_LUI: begin
        reg_write_o = 1'b1;
        alu_src_a_o = 1'b0; // rs1
        alu_src_b_o = 1'b1; // immediate (upper 20 bits << 12)
        alu_op_o    = ALU_ADD;
      end

      // U-type: AUIPC
      OP_AUIPC: begin
        reg_write_o = 1'b1;
        alu_src_a_o = 1'b1; // PC
        alu_src_b_o = 1'b1; // immediate
        alu_op_o    = ALU_ADD;
      end

      // J-type: JAL
      OP_JAL: begin
        reg_write_o  = 1'b1;
        result_src_o = RESULT_PC4;
        branch_o     = 1'b1;
        branch_op_o  = BRANCH_JAL;
        alu_src_a_o  = 1'b1; // PC
        alu_src_b_o  = 1'b1; // immediate
        alu_op_o     = ALU_ADD;
      end

      // I-type: JALR
      OP_JALR: begin
        reg_write_o  = 1'b1;
        result_src_o = RESULT_PC4;
        branch_o     = 1'b1;
        branch_op_o  = BRANCH_JAL;
        alu_src_a_o  = 1'b0; // rs1
        alu_src_b_o  = 1'b1; // immediate
        alu_op_o     = ALU_ADD;
      end

      // FENCE, SYSTEM (NOP)
      OP_FENCE, OP_SYSTEM: begin
      end

      default: begin
      end
    endcase
  end

endmodule
