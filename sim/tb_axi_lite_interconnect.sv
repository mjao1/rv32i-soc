module tb_axi_lite_interconnect ();

  localparam logic [31:0] DMEM_BASE = 32'h0000_0000;
  localparam int DMEM_BYTES = 4096;
  localparam logic [31:0] GPIO_BASE = 32'h1000_0000;
  localparam int GPIO_BYTES = 4096;
  localparam logic [31:0] UART_BASE = 32'h1000_1000;
  localparam int UART_BYTES = 4096;
  localparam logic [31:0] TIMER_BASE = 32'h1000_2000;
  localparam int TIMER_BYTES = 4096;

  logic clk_w;
  logic rst_w;

  logic [31:0] gpio_i_w;
  logic [31:0] gpio_o_w;

  logic uart_rx_drv_w;
  logic uart_loopback_w;
  logic uart_rx_w;
  logic uart_tx_w;

  assign uart_rx_w = uart_loopback_w ? uart_tx_w : uart_rx_drv_w;

  logic [31:0] m_axi_awaddr;
  logic [2:0] m_axi_awprot;
  logic m_axi_awvalid;
  logic m_axi_awready;

  logic [31:0] m_axi_wdata;
  logic [3:0] m_axi_wstrb;
  logic m_axi_wvalid;
  logic m_axi_wready;

  logic [1:0] m_axi_bresp;
  logic m_axi_bvalid;
  logic m_axi_bready;

  logic [31:0] m_axi_araddr;
  logic [2:0] m_axi_arprot;
  logic m_axi_arvalid;
  logic m_axi_arready;

  logic [31:0] m_axi_rdata;
  logic [1:0] m_axi_rresp;
  logic m_axi_rvalid;
  logic m_axi_rready;

  axi_lite_interconnect #(
    .DMEM_BASE (DMEM_BASE),
    .DMEM_BYTES (DMEM_BYTES),
    .GPIO_BASE (GPIO_BASE),
    .GPIO_BYTES (GPIO_BYTES),
    .UART_BASE (UART_BASE),
    .UART_BYTES (UART_BYTES),
    .TIMER_BASE (TIMER_BASE),
    .TIMER_BYTES (TIMER_BYTES)
  ) u_ic (
    .clk_i (clk_w),
    .rst_i (rst_w),
    .gpio_i (gpio_i_w),
    .gpio_o (gpio_o_w),
    .uart_rx_i (uart_rx_w),
    .uart_tx_o (uart_tx_w),
    .m_axi_awaddr (m_axi_awaddr),
    .m_axi_awprot (m_axi_awprot),
    .m_axi_awvalid (m_axi_awvalid),
    .m_axi_awready (m_axi_awready),
    .m_axi_wdata (m_axi_wdata),
    .m_axi_wstrb (m_axi_wstrb),
    .m_axi_wvalid (m_axi_wvalid),
    .m_axi_wready (m_axi_wready),
    .m_axi_bresp (m_axi_bresp),
    .m_axi_bvalid (m_axi_bvalid),
    .m_axi_bready (m_axi_bready),
    .m_axi_araddr (m_axi_araddr),
    .m_axi_arprot (m_axi_arprot),
    .m_axi_arvalid (m_axi_arvalid),
    .m_axi_arready (m_axi_arready),
    .m_axi_rdata (m_axi_rdata),
    .m_axi_rresp (m_axi_rresp),
    .m_axi_rvalid (m_axi_rvalid),
    .m_axi_rready (m_axi_rready)
  );

  initial clk_w = 0;
  always #5 clk_w = ~clk_w;

  int test_count_r;
  int pass_count_r;

  task automatic idle_master();
    m_axi_awaddr = 32'b0;
    m_axi_awprot = 3'b0;
    m_axi_awvalid = 1'b0;
    m_axi_wdata = 32'b0;
    m_axi_wstrb = 4'b0;
    m_axi_wvalid = 1'b0;
    m_axi_bready = 1'b0;
    m_axi_araddr = 32'b0;
    m_axi_arprot = 3'b0;
    m_axi_arvalid = 1'b0;
    m_axi_rready = 1'b0;
    uart_rx_drv_w = 1'b1;
  endtask

  // Cycles per bit; keep in sync with UART DIV register (default 100 in RTL)
  int uart_bit_cycles_r;

  task automatic uart_serial_rx_byte(input logic [7:0] byte_data);
    int k;
    int bc;
    bc = uart_bit_cycles_r;
    @(posedge clk_w);
    #1;
    uart_rx_drv_w = 1'b0;
    repeat (bc) @(posedge clk_w);
    for (k = 0; k < 8; k++) begin
      uart_rx_drv_w = byte_data[k];
      repeat (bc) @(posedge clk_w);
    end
    uart_rx_drv_w = 1'b1;
    repeat (bc) @(posedge clk_w);
  endtask

  task automatic axi_write_word(
    input logic [31:0] addr,
    input logic [31:0] data,
    input logic [3:0] strb,
    output logic [1:0] bresp_o
  );
    idle_master();
    @(posedge clk_w);
    #1;
    m_axi_awaddr = addr;
    m_axi_awvalid = 1'b1;
    m_axi_wdata = data;
    m_axi_wstrb = strb;
    m_axi_wvalid = 1'b1;
    do @(posedge clk_w); while (!(m_axi_awready && m_axi_wready));
    @(posedge clk_w);
    #1;
    m_axi_awvalid = 1'b0;
    m_axi_wvalid = 1'b0;
    m_axi_bready = 1'b1;
    do @(posedge clk_w); while (!m_axi_bvalid);
    bresp_o = m_axi_bresp;
    @(posedge clk_w);
    #1;
    m_axi_bready = 1'b0;
  endtask

  task automatic axi_write_aw_then_w(
    input logic [31:0] addr,
    input logic [31:0] data,
    input logic [3:0] strb,
    output logic [1:0] bresp_o
  );
    idle_master();
    @(posedge clk_w);
    #1;
    m_axi_awaddr = addr;
    m_axi_awvalid = 1'b1;
    m_axi_wdata = data;
    m_axi_wstrb = strb;
    m_axi_wvalid = 1'b0;
    do @(posedge clk_w); while (!m_axi_awready);
    @(posedge clk_w);
    #1;
    m_axi_awvalid = 1'b0;
    m_axi_wvalid = 1'b1;
    do @(posedge clk_w); while (!m_axi_wready);
    @(posedge clk_w);
    #1;
    m_axi_wvalid = 1'b0;
    m_axi_bready = 1'b1;
    do @(posedge clk_w); while (!m_axi_bvalid);
    bresp_o = m_axi_bresp;
    @(posedge clk_w);
    #1;
    m_axi_bready = 1'b0;
  endtask

  task automatic axi_read_word(
    input logic [31:0] addr,
    output logic [31:0] data_o,
    output logic [1:0] rresp_o
  );
    idle_master();
    @(posedge clk_w);
    #1;
    m_axi_araddr = addr;
    m_axi_arvalid = 1'b1;
    do @(posedge clk_w); while (!m_axi_arready);
    @(posedge clk_w);
    #1;
    m_axi_arvalid = 1'b0;
    m_axi_rready = 1'b1;
    do @(posedge clk_w); while (!m_axi_rvalid);
    data_o = m_axi_rdata;
    rresp_o = m_axi_rresp;
    @(posedge clk_w);
    #1;
    m_axi_rready = 1'b0;
  endtask

  initial begin
    idle_master();
    rst_w = 1'b1;
    @(posedge clk_w);
    @(posedge clk_w);
    rst_w = 1'b0;
    @(posedge clk_w);

    gpio_i_w = 32'h0000_0000;
    uart_loopback_w = 1'b0;
    uart_rx_drv_w = 1'b1;
    uart_bit_cycles_r = 100;

    test_count_r = 0;
    pass_count_r = 0;

    begin
      logic [1:0] bresp;
      logic [31:0] rdata;
      logic [1:0] rresp;

      // Word write @ 0x0000 then read back (OKAY)
      test_count_r++;
      axi_write_word(32'h0000_0000, 32'hDEAD_BEEF, 4'b1111, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: write bresp=%0d expected OKAY", bresp);

      test_count_r++;
      axi_read_word(32'h0000_0000, rdata, rresp);
      if (rdata === 32'hDEAD_BEEF && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: read data=0x%08h resp=%0d", rdata, rresp);

      // Byte write using strb
      test_count_r++;
      axi_write_word(32'h0000_0004, 32'h0000_00AA, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: byte write bresp");

      test_count_r++;
      axi_read_word(32'h0000_0004, rdata, rresp);
      if (rdata === 32'h0000_00AA && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: byte read data=0x%08h", rdata);

      // AW then W ordering
      test_count_r++;
      axi_write_aw_then_w(32'h0000_0010, 32'hCAFE_0001, 4'b1111, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: aw_then_w bresp=%0d", bresp);

      test_count_r++;
      axi_read_word(32'h0000_0010, rdata, rresp);
      if (rdata === 32'hCAFE_0001 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: aw_then_w read");

      // GPIO: DIR all outputs, DATA drives gpio_o
      test_count_r++;
      axi_write_word(GPIO_BASE + 32'h4, 32'hFFFF_FFFF, 4'b1111, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: gpio DIR write bresp");

      test_count_r++;
      axi_write_word(GPIO_BASE + 32'h0, 32'h1234_5678, 4'b1111, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: gpio DATA write bresp");

      test_count_r++;
      if (gpio_o_w === 32'h1234_5678)
        pass_count_r++;
      else
        $display("FAIL: gpio_o=0x%08h expected 0x12345678", gpio_o_w);

      test_count_r++;
      axi_read_word(GPIO_BASE + 32'h4, rdata, rresp);
      if (rdata === 32'hFFFF_FFFF && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: gpio DIR read data=0x%08h", rdata);

      test_count_r++;
      axi_read_word(GPIO_BASE + 32'h0, rdata, rresp);
      if (rdata === 32'h1234_5678 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: gpio DATA read data=0x%08h", rdata);

      // Mixed input/output: bits 0-3 output, upper bits read pads
      test_count_r++;
      axi_write_word(GPIO_BASE + 32'h4, 32'h0000_000F, 4'b1111, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: gpio DIR mask write");

      gpio_i_w = 32'hFFFF_FFF0;
      @(posedge clk_w);

      test_count_r++;
      axi_write_word(GPIO_BASE + 32'h0, 32'h0000_000A, 4'b1111, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: gpio DATA nibble write");

      test_count_r++;
      axi_read_word(GPIO_BASE + 32'h0, rdata, rresp);
      if (rdata === 32'hFFFF_FFFA && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: gpio mixed read data=0x%08h expected 0xffff_fffa", rdata);

      // UART: DIV reset value
      test_count_r++;
      axi_read_word(UART_BASE + 32'h8, rdata, rresp);
      if (rdata === 32'd100 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart DIV reset read 0x%08h", rdata);

      // UART: TX byte via DATA; wait for serializer (10 bits * DIV cycles)
      test_count_r++;
      axi_write_word(UART_BASE + 32'h0, 32'h0000_0042, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart TX write bresp");

      test_count_r++;
      repeat (uart_bit_cycles_r * 12) @(posedge clk_w);
      axi_read_word(UART_BASE + 32'h4, rdata, rresp);
      if (rdata[1] === 1'b1 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart STAT after TX (expect TXE) 0x%08h", rdata);

      // UART: serial RX 0xA5, STATUS then DATA read
      uart_serial_rx_byte(8'hA5);
      test_count_r++;
      axi_read_word(UART_BASE + 32'h4, rdata, rresp);
      if (rdata[1:0] === 2'b11 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart STAT read 0x%08h", rdata);

      test_count_r++;
      axi_read_word(UART_BASE + 32'h0, rdata, rresp);
      if (rdata[7:0] === 8'hA5 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart RX DATA read 0x%08h", rdata);

      // UART: program DIV and read back (short bit time for following serial tests)
      test_count_r++;
      axi_write_word(UART_BASE + 32'h8, 32'd80, 4'b1111, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart DIV write bresp");

      test_count_r++;
      axi_read_word(UART_BASE + 32'h8, rdata, rresp);
      if (rdata === 32'd80 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart DIV read back 0x%08h", rdata);

      uart_bit_cycles_r = 80;

      // UART: duplicate DATA write while TX hold full (second byte queued, third -> SLVERR)
      test_count_r++;
      axi_write_word(UART_BASE + 32'h0, 32'h0000_00AA, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart dup test first DATA write bresp");

      test_count_r++;
      axi_write_word(UART_BASE + 32'h0, 32'h0000_00BB, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart dup test second DATA write bresp");

      test_count_r++;
      axi_write_word(UART_BASE + 32'h0, 32'h0000_00CC, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_SLVERR)
        pass_count_r++;
      else
        $display("FAIL: uart duplicate DATA write bresp=%0d expected SLVERR", bresp);

      // Drain queued byte and finish any in-flight TX so UART is idle
      repeat (uart_bit_cycles_r * 24) @(posedge clk_w);

      // UART: TX/RX loopback (uart_rx tied to uart_tx)
      uart_loopback_w = 1'b1;
      test_count_r++;
      axi_write_word(UART_BASE + 32'h0, 32'h0000_0033, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart loopback TX write bresp");

      repeat (uart_bit_cycles_r * 14) @(posedge clk_w);
      test_count_r++;
      axi_read_word(UART_BASE + 32'h4, rdata, rresp);
      if (rdata[0] === 1'b1 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart loopback STAT (expect RXNE) 0x%08h", rdata);

      test_count_r++;
      axi_read_word(UART_BASE + 32'h0, rdata, rresp);
      if (rdata[7:0] === 8'h33 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart loopback DATA 0x%08h", rdata);

      uart_loopback_w = 1'b0;

      // UART: RX overrun — two frames without reading DATA (sticky OVERRUN in STAT[3])
      uart_serial_rx_byte(8'h11);
      uart_serial_rx_byte(8'h22);
      test_count_r++;
      axi_read_word(UART_BASE + 32'h4, rdata, rresp);
      if (rdata[3] === 1'b1 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart overrun STAT 0x%08h (expect OVERRUN)", rdata);

      test_count_r++;
      axi_read_word(UART_BASE + 32'h0, rdata, rresp);
      if (rdata[7:0] === 8'h11 && rresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: uart overrun first DATA 0x%08h", rdata);

      // Restore default DIV for any later logic
      axi_write_word(UART_BASE + 32'h8, 32'd100, 4'b1111, bresp);
      uart_bit_cycles_r = 100;

      // Timer: enable, run, COUNT increases
      test_count_r++;
      axi_write_word(TIMER_BASE + 32'h8, 32'h0000_0001, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_OKAY)
        pass_count_r++;
      else
        $display("FAIL: timer CTRL write");

      repeat (25) @(posedge clk_w);

      test_count_r++;
      axi_read_word(TIMER_BASE + 32'h0, rdata, rresp);
      if ((rdata >= 32'd20) && (rresp === axi4_lite_pkg::RESP_OKAY))
        pass_count_r++;
      else
        $display("FAIL: timer COUNT read 0x%08h (expected >= 20)", rdata);

      // Unmapped write/read -> DECERR
      test_count_r++;
      axi_write_word(DMEM_BASE + DMEM_BYTES, 32'h1, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_DECERR)
        pass_count_r++;
      else
        $display("FAIL: unmapped write bresp=%0d expected DECERR", bresp);

      test_count_r++;
      axi_read_word(DMEM_BASE + DMEM_BYTES, rdata, rresp);
      if (rresp === axi4_lite_pkg::RESP_DECERR)
        pass_count_r++;
      else
        $display("FAIL: unmapped read resp=%0d expected DECERR", rresp);
    end

    $display("PASSED: %0d", pass_count_r);
    $display("FAILED: %0d", test_count_r - pass_count_r);

    $finish;
  end

endmodule
