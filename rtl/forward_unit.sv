module forward_unit (
  input logic [4:0] id_ex_rs1_addr_i,
  input logic [4:0] id_ex_rs2_addr_i,
  input logic [31:0] id_ex_rs1_data_i,
  input logic [31:0] id_ex_rs2_data_i,
  input logic ex_mem_reg_write_i,
  input logic [4:0] ex_mem_rd_i,
  input logic [1:0] ex_mem_result_src_i,
  input logic [31:0] ex_mem_alu_res_i,
  input logic mem_wb_reg_write_i,
  input logic [4:0] mem_wb_rd_i,
  input logic [31:0] mem_wb_data_i,
  output logic [31:0] rs1_fwd_o,
  output logic [31:0] rs2_fwd_o
);

  always_comb begin
    if (ex_mem_reg_write_i && ex_mem_rd_i != 5'b0 && ex_mem_rd_i == id_ex_rs1_addr_i && ex_mem_result_src_i != rv32i_pkg::RESULT_MEM)
      rs1_fwd_o = ex_mem_alu_res_i;
    else if (mem_wb_reg_write_i && mem_wb_rd_i != 5'b0 && mem_wb_rd_i == id_ex_rs1_addr_i)
      rs1_fwd_o = mem_wb_data_i;
    else
      rs1_fwd_o = id_ex_rs1_data_i;

    if (ex_mem_reg_write_i && ex_mem_rd_i != 5'b0 && ex_mem_rd_i == id_ex_rs2_addr_i && ex_mem_result_src_i != rv32i_pkg::RESULT_MEM)
      rs2_fwd_o = ex_mem_alu_res_i;
    else if (mem_wb_reg_write_i && mem_wb_rd_i != 5'b0 && mem_wb_rd_i == id_ex_rs2_addr_i)
      rs2_fwd_o = mem_wb_data_i;
    else
      rs2_fwd_o = id_ex_rs2_data_i;
  end

endmodule
