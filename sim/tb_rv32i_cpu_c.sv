module tb_rv32i_cpu_c import rv32i_pkg::*; ();
  localparam int IMEM_WORDS = 1024;
  localparam int CYCLES = 100000;
  localparam logic [31:0] DMEM_RAM_BASE = 32'h8000_0000;

  // IMEM preload buffer & golden return in a0 (x10)
  logic [31:0] imem_load[0:IMEM_WORDS-1];
  logic [31:0] expected_value;

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
    .IMEM_SIZE (IMEM_WORDS),
    .DMEM_SIZE (4096),
    .DMEM_BASE (DMEM_RAM_BASE)
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

  int i;

  initial clk_w = 0;
  always #5 clk_w = ~clk_w;

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

  initial begin
    $readmemh("test/programs/cpu_smoke.mem", imem_load);
    expected_value = 32'd5094;

    rst_w = 1'b1;
    imem_write_en_w = 1'b0;
    imem_write_addr_w = 32'b0;
    imem_write_data_w = 32'b0;
    @(posedge clk_w);
    #1;
    
    for (i = 0; i < IMEM_WORDS; i++) begin
      load_word(i * 4, imem_load[i]);
    end

    rst_w = 1'b0;

    repeat (CYCLES) @(posedge clk_w);
    #1;

    if (u_rv32i_cpu.u_register_file.regs_r[10] === expected_value) begin
      $display("PASSED: Return value a0 (x10) = %0d", expected_value);
    end else begin
      $display("FAIL: x10=0x%08h expected %0d", u_rv32i_cpu.u_register_file.regs_r[10], expected_value);
    end

    $finish;
  end

endmodule
