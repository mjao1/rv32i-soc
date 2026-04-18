module tb_axi_lite_interconnect ();

  localparam logic [31:0] DMEM_BASE = 32'h0000_0000;
  localparam int DMEM_BYTES = 4096;

  logic clk_w;
  logic rst_w;

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
    .DMEM_BYTES (DMEM_BYTES)
  ) u_ic (
    .clk_i (clk_w),
    .rst_i (rst_w),
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

      // Unmapped write / read -> SLVERR
      test_count_r++;
      axi_write_word(DMEM_BASE + DMEM_BYTES, 32'h1, 4'b0001, bresp);
      if (bresp === axi4_lite_pkg::RESP_SLVERR)
        pass_count_r++;
      else
        $display("FAIL: unmapped write bresp=%0d expected SLVERR", bresp);

      test_count_r++;
      axi_read_word(DMEM_BASE + DMEM_BYTES, rdata, rresp);
      if (rresp === axi4_lite_pkg::RESP_SLVERR)
        pass_count_r++;
      else
        $display("FAIL: unmapped read resp=%0d expected SLVERR", rresp);
    end

    $display("PASSED: %0d", pass_count_r);
    $display("FAILED: %0d", test_count_r - pass_count_r);

    $finish;
  end

endmodule
