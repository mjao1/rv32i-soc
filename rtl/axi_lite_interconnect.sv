module axi_lite_interconnect #(
  parameter logic [31:0] DMEM_BASE = 32'h0000_0000,
  parameter int DMEM_BYTES = 4096
) (
  input logic clk_i,
  input logic rst_i,

  input logic [31:0] m_axi_awaddr,
  input logic [2:0] m_axi_awprot,
  input logic m_axi_awvalid,
  output logic m_axi_awready,

  input logic [31:0] m_axi_wdata,
  input logic [3:0] m_axi_wstrb,
  input logic m_axi_wvalid,
  output logic m_axi_wready,

  output logic [1:0] m_axi_bresp,
  output logic m_axi_bvalid,
  input logic m_axi_bready,

  input logic [31:0] m_axi_araddr,
  input logic [2:0] m_axi_arprot,
  input logic m_axi_arvalid,
  output logic m_axi_arready,

  output logic [31:0] m_axi_rdata,
  output logic [1:0] m_axi_rresp,
  output logic m_axi_rvalid,
  input logic m_axi_rready
);

  function automatic logic hit_dmem(input logic [31:0] addr);
    return (addr >= DMEM_BASE) && (addr < (DMEM_BASE + DMEM_BYTES));
  endfunction

  logic wr_pending_r;
  logic wr_sel_dmem_r;

  wire route_dmem_w = wr_pending_r ? wr_sel_dmem_r : hit_dmem(m_axi_awaddr);

  wire dmem_awvalid = m_axi_awvalid && hit_dmem(m_axi_awaddr);
  wire err_awvalid = m_axi_awvalid && !hit_dmem(m_axi_awaddr);

  wire dmem_wvalid = m_axi_wvalid && route_dmem_w;
  wire err_wvalid = m_axi_wvalid && !route_dmem_w;

  wire ar_dmem = hit_dmem(m_axi_araddr);

  always_ff @(posedge clk_i) begin
    if (rst_i)
      wr_pending_r <= 1'b0;
    else begin
      if (m_axi_bvalid && m_axi_bready)
        wr_pending_r <= 1'b0;
      else if (m_axi_awvalid && m_axi_awready)
        wr_pending_r <= 1'b1;
    end
  end

  always_ff @(posedge clk_i) begin
    if (m_axi_awvalid && m_axi_awready)
      wr_sel_dmem_r <= hit_dmem(m_axi_awaddr);
  end

  logic dmem_awready;
  logic dmem_wready;
  logic [1:0] dmem_bresp;
  logic dmem_bvalid;
  logic dmem_arready;
  logic [31:0] dmem_rdata;
  logic [1:0] dmem_rresp;
  logic dmem_rvalid;

  logic err_awready;
  logic err_wready;
  logic [1:0] err_bresp;
  logic err_bvalid;
  logic err_arready;
  logic [31:0] err_rdata;
  logic [1:0] err_rresp;
  logic err_rvalid;

  axi_lite_dmem_slave #(
    .MEM_BYTES (DMEM_BYTES),
    .ADDR_BASE (DMEM_BASE)
  ) u_dmem (
    .clk_i (clk_i),
    .rst_i (rst_i),
    .s_axi_awaddr (m_axi_awaddr),
    .s_axi_awprot (m_axi_awprot),
    .s_axi_awvalid (dmem_awvalid),
    .s_axi_awready (dmem_awready),
    .s_axi_wdata (m_axi_wdata),
    .s_axi_wstrb (m_axi_wstrb),
    .s_axi_wvalid (dmem_wvalid),
    .s_axi_wready (dmem_wready),
    .s_axi_bresp (dmem_bresp),
    .s_axi_bvalid (dmem_bvalid),
    .s_axi_bready (m_axi_bready),
    .s_axi_araddr (m_axi_araddr),
    .s_axi_arprot (m_axi_arprot),
    .s_axi_arvalid (m_axi_arvalid && ar_dmem),
    .s_axi_arready (dmem_arready),
    .s_axi_rdata (dmem_rdata),
    .s_axi_rresp (dmem_rresp),
    .s_axi_rvalid (dmem_rvalid),
    .s_axi_rready (m_axi_rready)
  );

  axi_lite_err_slave u_err (
    .clk_i (clk_i),
    .rst_i (rst_i),
    .s_axi_awaddr (m_axi_awaddr),
    .s_axi_awprot (m_axi_awprot),
    .s_axi_awvalid (err_awvalid),
    .s_axi_awready (err_awready),
    .s_axi_wdata (m_axi_wdata),
    .s_axi_wstrb (m_axi_wstrb),
    .s_axi_wvalid (err_wvalid),
    .s_axi_wready (err_wready),
    .s_axi_bresp (err_bresp),
    .s_axi_bvalid (err_bvalid),
    .s_axi_bready (m_axi_bready),
    .s_axi_araddr (m_axi_araddr),
    .s_axi_arprot (m_axi_arprot),
    .s_axi_arvalid (m_axi_arvalid && !ar_dmem),
    .s_axi_arready (err_arready),
    .s_axi_rdata (err_rdata),
    .s_axi_rresp (err_rresp),
    .s_axi_rvalid (err_rvalid),
    .s_axi_rready (m_axi_rready)
  );

  assign m_axi_awready = hit_dmem(m_axi_awaddr) ? dmem_awready : err_awready;

  assign m_axi_wready = route_dmem_w ? dmem_wready : err_wready;

  assign m_axi_bvalid = dmem_bvalid || err_bvalid;
  assign m_axi_bresp = dmem_bvalid ? dmem_bresp : err_bresp;

  assign m_axi_arready = ar_dmem ? dmem_arready : err_arready;

  assign m_axi_rdata = dmem_rvalid ? dmem_rdata : err_rdata;
  assign m_axi_rresp = dmem_rvalid ? dmem_rresp : err_rresp;
  assign m_axi_rvalid = dmem_rvalid || err_rvalid;

endmodule
