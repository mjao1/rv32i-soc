module tb_rv32i_soc_c import rv32i_pkg::*; ();
  localparam int IMEM_WORDS = 1024;
  // AXI loads/stores take multiple cycles per access, allow headroom vs tb_rv32i_cpu_c.
  localparam int CYCLES = 500000;
  localparam logic [31:0] DMEM_RAM_BASE = 32'h8000_0000;

  // IMEM preload buffer & golden return in a0 (x10)
  logic [31:0] imem_load[0:IMEM_WORDS-1];
  logic [31:0] expected_value;

  logic clk_w;
  logic rst_w;
  logic imem_write_en_w;
  logic [31:0] imem_write_addr_w;
  logic [31:0] imem_write_data_w;

  logic [31:0] gpio_i_w;
  logic [31:0] gpio_o_w;
  logic uart_rx_w;
  logic uart_tx_w;
  logic [31:0] dbg_pc_nc;

  rv32i_soc #(
    .IMEM_SIZE (IMEM_WORDS),
    .DMEM_BYTES (4096),
    .DMEM_BASE (DMEM_RAM_BASE)
  ) u_soc (
    .clk_i (clk_w),
    .rst_i (rst_w),
    .imem_write_en_i (imem_write_en_w),
    .imem_write_addr_i (imem_write_addr_w),
    .imem_write_data_i (imem_write_data_w),
    .gpio_i (gpio_i_w),
    .gpio_o (gpio_o_w),
    .uart_rx_i (uart_rx_w),
    .uart_tx_o (uart_tx_w),
    .dbg_pc_o (dbg_pc_nc)
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
    $readmemh("test/programs/soc_c_smoke.mem", imem_load);
    expected_value = 32'd5094; // edit based on test program

    gpio_i_w = 32'b0;
    uart_rx_w = 1'b1;
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

    if (u_soc.u_cpu.u_register_file.regs_r[10] === expected_value) begin
      $display("PASSED: Return value a0 (x10) = %0d", expected_value);
    end else begin
      $display("FAIL: x10=0x%08h expected %0d", u_soc.u_cpu.u_register_file.regs_r[10], expected_value);
    end

    $finish;
  end

endmodule
