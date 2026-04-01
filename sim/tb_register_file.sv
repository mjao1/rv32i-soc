module tb_register_file ();
  logic clk_w;
  logic rst_w;
  logic [4:0] rs1_addr_w;
  logic [4:0] rs2_addr_w;
  logic [4:0] rd_addr_w;
  logic [31:0] rd_data_w;
  logic reg_write_w;
  logic [31:0] rs1_data_w;
  logic [31:0] rs2_data_w;

  register_file u_register_file (
    .clk_i (clk_w),
    .rst_i (rst_w),
    .rs1_addr_i (rs1_addr_w),
    .rs2_addr_i (rs2_addr_w),
    .rd_addr_i (rd_addr_w),
    .rd_data_i (rd_data_w),
    .reg_write_i (reg_write_w),
    .rs1_data_o (rs1_data_w),
    .rs2_data_o (rs2_data_w)
  );

  int test_count_r = 0;
  int pass_count_r = 0;

  initial clk_w = 0;
  always #5 clk_w = ~clk_w;

  task automatic write_reg(
    input logic [4:0] addr,
    input logic [31:0] data
  );
    rd_addr_w = addr;
    rd_data_w = data;
    reg_write_w = 1'b1;
    @(posedge clk_w);
    #1;
    reg_write_w = 1'b0;
  endtask

  task automatic check_read(
    input string name,
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [31:0] expected_rs1,
    input logic [31:0] expected_rs2
  );
    rs1_addr_w = rs1_addr;
    rs2_addr_w = rs2_addr;
    #1;

    test_count_r++;
    if (rs1_data_w === expected_rs1 && rs2_data_w === expected_rs2) begin
      pass_count_r++;
    end else begin
      $display("FAIL: %-20s | rs1[%0d]=0x%08h (exp 0x%08h) rs2[%0d]=0x%08h (exp 0x%08h)",
               name, rs1_addr, rs1_data_w, expected_rs1,
               rs2_addr, rs2_data_w, expected_rs2);
    end
  endtask

  initial begin
    rst_w = 1'b1;
    reg_write_w = 1'b0;
    rd_addr_w = 5'b0;
    rd_data_w = 32'b0;
    rs1_addr_w = 5'b0;
    rs2_addr_w = 5'b0;
    @(posedge clk_w);
    #1;
    rst_w = 1'b0;

    // x0 reads as zero after reset
    check_read("x0 after reset", 5'd0, 5'd0, 32'h0, 32'h0);

    // Write x1, read back
    write_reg(5'd1, 32'hDEAD_BEEF);
    check_read("write x1", 5'd1, 5'd0, 32'hDEAD_BEEF, 32'h0);

    // Write x2, read x1 and x2 simultaneously
    write_reg(5'd2, 32'hCAFE_BABE);
    check_read("write x2", 5'd1, 5'd2, 32'hDEAD_BEEF, 32'hCAFE_BABE);

    // Write to x0 must be ignored
    write_reg(5'd0, 32'hFFFF_FFFF);
    check_read("x0 stays zero", 5'd0, 5'd1, 32'h0, 32'hDEAD_BEEF);

    // Overwrite x1
    write_reg(5'd1, 32'h1234_5678);
    check_read("overwrite x1", 5'd1, 5'd2, 32'h1234_5678, 32'hCAFE_BABE);

    // No write
    rd_addr_w = 5'd1;
    rd_data_w = 32'hAAAA_AAAA;
    reg_write_w = 1'b0;
    @(posedge clk_w);
    #1;
    check_read("wen=0 no write", 5'd1, 5'd2, 32'h1234_5678, 32'hCAFE_BABE);

    // Write to last register x31
    write_reg(5'd31, 32'h8000_0001);
    check_read("write x31", 5'd31, 5'd0, 32'h8000_0001, 32'h0);

    // Write multiple, verify isolation
    write_reg(5'd10, 32'h0000_000A);
    write_reg(5'd20, 32'h0000_0014);
    check_read("x10 and x20", 5'd10, 5'd20, 32'h0000_000A, 32'h0000_0014);

    // Reset
    rst_w = 1'b1;
    @(posedge clk_w);
    #1;
    rst_w = 1'b0;
    check_read("x1 after rst", 5'd1, 5'd2, 32'h0, 32'h0);
    check_read("x31 after rst", 5'd31, 5'd10, 32'h0, 32'h0);

    $display("PASSED: %0d", pass_count_r);
    $display("FAILED: %0d", test_count_r - pass_count_r);

    $finish;
  end

endmodule
