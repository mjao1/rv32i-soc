module register_file (
  input logic clk_i,
  input logic rst_i,
  input logic [4:0] rs1_addr_i,
  input logic [4:0] rs2_addr_i,
  input logic [4:0] rd_addr_i,
  input logic [31:0] rd_data_i,
  input logic reg_write_i,
  output logic [31:0] rs1_data_o,
  output logic [31:0] rs2_data_o,
  input logic [4:0] ex_rs1_addr_i,
  input logic [4:0] ex_rs2_addr_i,
  output logic [31:0] ex_rs1_data_o,
  output logic [31:0] ex_rs2_data_o
);

  logic [31:0] regs_r [0:31];

  // Async read with same cycle WB bypass (ID read vs WB write to same rd)
  assign rs1_data_o = (reg_write_i && rd_addr_i != 5'b0 && rd_addr_i == rs1_addr_i) ? rd_data_i : regs_r[rs1_addr_i];
  assign rs2_data_o = (reg_write_i && rd_addr_i != 5'b0 && rd_addr_i == rs2_addr_i) ? rd_data_i : regs_r[rs2_addr_i];

  assign ex_rs1_data_o = (reg_write_i && rd_addr_i != 5'b0 && rd_addr_i == ex_rs1_addr_i) ? rd_data_i : regs_r[ex_rs1_addr_i];
  assign ex_rs2_data_o = (reg_write_i && rd_addr_i != 5'b0 && rd_addr_i == ex_rs2_addr_i) ? rd_data_i : regs_r[ex_rs2_addr_i];

  // Sync write
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      for (int i = 0; i < 32; i++)
        regs_r[i] <= 32'b0;
    end else if (reg_write_i && rd_addr_i != 5'b0) begin
      regs_r[rd_addr_i] <= rd_data_i;
    end
  end

endmodule
