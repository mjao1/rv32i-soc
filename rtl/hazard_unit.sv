module hazard_unit (
  input logic [4:0] id_ex_rs1_i,
  input logic [4:0] id_ex_rs2_i,
  input logic ex_mem_reg_write_i,
  input logic [1:0] ex_mem_result_src_i,
  input logic [4:0] ex_mem_rd_i,
  output logic stall_if_o
);

  assign stall_if_o = ex_mem_reg_write_i && (ex_mem_result_src_i == rv32i_pkg::RESULT_MEM) && (ex_mem_rd_i != 5'b0) && (((ex_mem_rd_i == id_ex_rs1_i) && (id_ex_rs1_i != 5'b0)) || ((ex_mem_rd_i == id_ex_rs2_i) && (id_ex_rs2_i != 5'b0)));

endmodule
