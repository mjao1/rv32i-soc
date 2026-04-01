module alu import rv32i_pkg::*; (
  input logic [31:0] operand_a_i,
  input logic [31:0] operand_b_i,
  input alu_op_t alu_op_i,
  output logic [31:0] alu_result_o
);

  always_comb begin
    case (alu_op_i)
      ALU_ADD:  alu_result_o = operand_a_i + operand_b_i;
      ALU_SUB:  alu_result_o = operand_a_i - operand_b_i;
      ALU_AND:  alu_result_o = operand_a_i & operand_b_i;
      ALU_OR:   alu_result_o = operand_a_i | operand_b_i;
      ALU_XOR:  alu_result_o = operand_a_i ^ operand_b_i;
      ALU_SLT:  alu_result_o = {31'b0, $signed(operand_a_i) < $signed(operand_b_i)};
      ALU_SLTU: alu_result_o = {31'b0, operand_a_i < operand_b_i};
      ALU_SLL:  alu_result_o = operand_a_i << operand_b_i[4:0];
      ALU_SRL:  alu_result_o = operand_a_i >> operand_b_i[4:0];
      ALU_SRA:  alu_result_o = $unsigned($signed(operand_a_i) >>> operand_b_i[4:0]);
      default:  alu_result_o = 32'b0;
    endcase
  end

endmodule
