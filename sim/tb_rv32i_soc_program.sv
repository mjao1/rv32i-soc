/* Parameterized SoC testbench: runs any program built via `make TEST=<name>`.
 * Plusargs (optional):
 *   +MEM=<path>         hex image to $readmemh into IMEM
 *                       (default: test/programs/soc_program_1.mem)
 *   +EXPECT=<hex>       expected value of a0 (x10); if omitted the test
 *                       just prints the final a0 and exits without FAIL
 *   +CYCLES=<d>         cycle cap (default 500_000)
 *   +LOOPBACK           tie uart_rx <- uart_tx for echo programs
 *   +EARLY_EXIT         pass as soon as a0 matches +EXPECT 
 */
module tb_rv32i_soc_program import rv32i_pkg::*; ();
  localparam int IMEM_WORDS = 1024;
  localparam logic [31:0] DMEM_RAM_BASE = 32'h8000_0000;

  logic [31:0] imem_load[0:IMEM_WORDS-1];

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

  // Runtime config (set from plusargs)
  string mem_path;
  int unsigned cycles_budget;
  bit loopback_en;
  bit early_exit_en;
  bit has_expect;
  logic [31:0] expected_value;

  // Quiet RX idle line used when loopback is disabled
  logic uart_rx_idle_w;

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

  assign uart_rx_w = loopback_en ? uart_tx_w : uart_rx_idle_w;

  wire [31:0] a0_w = u_soc.u_cpu.u_register_file.regs_r[10];

  int i;

  initial clk_w = 0;
  always #5 clk_w = ~clk_w;

  task automatic load_word(input logic [31:0] addr, input logic [31:0] data);
    imem_write_addr_w = addr;
    imem_write_data_w = data;
    imem_write_en_w   = 1'b1;
    @(posedge clk_w);
    #1;
    imem_write_en_w   = 1'b0;
  endtask

  initial begin
    int unsigned expect_tmp;
    int unsigned cycles_tmp;
    string mem_tmp;

    mem_path       = "test/programs/soc_program_1.mem";
    cycles_budget  = 500_000;
    loopback_en    = 1'b0;
    early_exit_en  = 1'b0;
    has_expect     = 1'b0;
    expected_value = 32'h0;

    if ($value$plusargs("MEM=%s", mem_tmp)) mem_path = mem_tmp;
    if ($value$plusargs("CYCLES=%d", cycles_tmp)) cycles_budget = cycles_tmp;
    if ($value$plusargs("EXPECT=%h", expect_tmp)) begin
      has_expect     = 1'b1;
      expected_value = expect_tmp;
    end
    if ($test$plusargs("LOOPBACK")) loopback_en = 1'b1;
    if ($test$plusargs("EARLY_EXIT")) early_exit_en = 1'b1;

    $display("INFO: mem=%s cycles=%0d loopback=%0d early_exit=%0d expect=%s%08h",
             mem_path, cycles_budget, loopback_en, early_exit_en,
             has_expect ? "0x" : "--", expected_value);

    for (i = 0; i < IMEM_WORDS; i++) imem_load[i] = 32'h0;
    $readmemh(mem_path, imem_load);

    gpio_i_w          = 32'b0;
    uart_rx_idle_w    = 1'b1;
    rst_w             = 1'b1;
    imem_write_en_w   = 1'b0;
    imem_write_addr_w = 32'b0;
    imem_write_data_w = 32'b0;
    @(posedge clk_w);
    #1;

    for (i = 0; i < IMEM_WORDS; i++) begin
      load_word(i * 4, imem_load[i]);
    end

    rst_w = 1'b0;

    fork
      begin : watchdog
        repeat (cycles_budget) @(posedge clk_w);
        #1;
        if (has_expect) begin
          if (a0_w === expected_value)
            $display("PASSED: a0 = 0x%08h matches expected", a0_w);
          else
            $display("FAIL: a0 = 0x%08h expected 0x%08h", a0_w, expected_value);
        end else begin
          $display("DONE: a0 = 0x%08h (no +EXPECT provided)", a0_w);
        end
        $finish;
      end
      begin : early
        if (early_exit_en && has_expect) begin
          wait (a0_w === expected_value);
          repeat (200) @(posedge clk_w);
          $display("PASSED: a0 = 0x%08h (early exit)", a0_w);
          $finish;
        end
      end
    join
  end

endmodule
