module tb_rv32i_soc_integration import rv32i_pkg::*; ();
  localparam int IMEM_WORDS = 1024;
  localparam int CYCLES = 2_000_000;
  localparam logic [31:0] DMEM_RAM_BASE = 32'h8000_0000;
  localparam logic [31:0] EXPECTED = 32'h0000_000F;

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

  // UART loopback: TX -> RX on the same SoC
  assign uart_rx_w = uart_tx_w;

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

  logic [31:0] a0_w;
  assign a0_w = u_soc.u_cpu.u_register_file.regs_r[10];

  initial begin
    $readmemh("test/programs/soc_c_integration.mem", imem_load);

    gpio_i_w = 32'b0;
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

    // Run until either the expected bitmap shows up in a0 or cap is hit
    fork
      begin : watchdog
        repeat (CYCLES) @(posedge clk_w);
        #1;
        if (a0_w === EXPECTED) begin
          $display("PASSED: a0=0x%08h (DMEM+GPIO+TIMER+UART)", a0_w);
        end else begin
          $display("FAIL: a0=0x%08h expected 0x%08h bitmap(dmem=%0d,gpio=%0d,timer=%0d,uart=%0d)", a0_w, EXPECTED, a0_w[0], a0_w[1], a0_w[2], a0_w[3]);
        end
        $finish;
      end
      begin : early_exit
        wait (a0_w === EXPECTED);
        repeat (200) @(posedge clk_w);
        $display("PASSED: a0=0x%08h (DMEM+GPIO+TIMER+UART)", a0_w);
        $finish;
      end
    join
  end

endmodule
