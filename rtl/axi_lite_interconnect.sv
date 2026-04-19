// Single AXI4-Lite master -> DMEM, GPIO, UART, TIMER, or error slave (decode miss).
// Latches write target on AW handshake so W may follow later.
module axi_lite_interconnect #(
  parameter logic [31:0] DMEM_BASE = 32'h0000_0000,
  parameter int DMEM_BYTES = 4096,
  parameter logic [31:0] GPIO_BASE = 32'h1000_0000,
  parameter int GPIO_BYTES = 4096,
  parameter logic [31:0] UART_BASE = 32'h1000_1000,
  parameter int UART_BYTES = 4096,
  parameter logic [31:0] TIMER_BASE = 32'h1000_2000,
  parameter int TIMER_BYTES = 4096
) (
  input logic clk_i,
  input logic rst_i,

  input logic [31:0] gpio_i,
  output logic [31:0] gpio_o,

  input logic uart_rx_i,
  output logic uart_tx_o,

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

  // Address decode: regions must not overlap
  localparam logic [2:0] WR_DMEM = 3'd0;
  localparam logic [2:0] WR_GPIO = 3'd1;
  localparam logic [2:0] WR_UART = 3'd2;
  localparam logic [2:0] WR_TIMER = 3'd3;
  localparam logic [2:0] WR_ERR = 3'd4;

  function automatic logic hit_dmem(input logic [31:0] addr);
    return (addr >= DMEM_BASE) && (addr < (DMEM_BASE + DMEM_BYTES));
  endfunction

  function automatic logic hit_gpio(input logic [31:0] addr);
    return (addr >= GPIO_BASE) && (addr < (GPIO_BASE + GPIO_BYTES));
  endfunction

  function automatic logic hit_uart(input logic [31:0] addr);
    return (addr >= UART_BASE) && (addr < (UART_BASE + UART_BYTES));
  endfunction

  function automatic logic hit_timer(input logic [31:0] addr);
    return (addr >= TIMER_BASE) && (addr < (TIMER_BASE + TIMER_BYTES));
  endfunction

  function automatic logic [2:0] wr_decode(input logic [31:0] addr);
    if (hit_dmem(addr))
      return WR_DMEM;
    if (hit_gpio(addr))
      return WR_GPIO;
    if (hit_uart(addr))
      return WR_UART;
    if (hit_timer(addr))
      return WR_TIMER;
    return WR_ERR;
  endfunction

  logic wr_pending_r;
  logic [2:0] wr_tgt_r;

  wire [2:0] route_w = wr_pending_r ? wr_tgt_r : wr_decode(m_axi_awaddr);

  wire dmem_awvalid = m_axi_awvalid && hit_dmem(m_axi_awaddr);
  wire gpio_awvalid = m_axi_awvalid && hit_gpio(m_axi_awaddr);
  wire uart_awvalid = m_axi_awvalid && hit_uart(m_axi_awaddr);
  wire timer_awvalid = m_axi_awvalid && hit_timer(m_axi_awaddr);
  wire err_awvalid =
      m_axi_awvalid && !hit_dmem(m_axi_awaddr) && !hit_gpio(m_axi_awaddr) &&
      !hit_uart(m_axi_awaddr) && !hit_timer(m_axi_awaddr);

  wire dmem_wvalid = m_axi_wvalid && (route_w == WR_DMEM);
  wire gpio_wvalid = m_axi_wvalid && (route_w == WR_GPIO);
  wire uart_wvalid = m_axi_wvalid && (route_w == WR_UART);
  wire timer_wvalid = m_axi_wvalid && (route_w == WR_TIMER);
  wire err_wvalid = m_axi_wvalid && (route_w == WR_ERR);

  wire ar_dmem = hit_dmem(m_axi_araddr);
  wire ar_gpio = hit_gpio(m_axi_araddr);
  wire ar_uart = hit_uart(m_axi_araddr);
  wire ar_timer = hit_timer(m_axi_araddr);

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
      wr_tgt_r <= wr_decode(m_axi_awaddr);
  end

  logic dmem_awready;
  logic dmem_wready;
  logic [1:0] dmem_bresp;
  logic dmem_bvalid;
  logic dmem_arready;
  logic [31:0] dmem_rdata;
  logic [1:0] dmem_rresp;
  logic dmem_rvalid;

  logic gpio_awready;
  logic gpio_wready;
  logic [1:0] gpio_bresp;
  logic gpio_bvalid;
  logic gpio_arready;
  logic [31:0] gpio_rdata;
  logic [1:0] gpio_rresp;
  logic gpio_rvalid;

  logic uart_awready;
  logic uart_wready;
  logic [1:0] uart_bresp;
  logic uart_bvalid;
  logic uart_arready;
  logic [31:0] uart_rdata;
  logic [1:0] uart_rresp;
  logic uart_rvalid;

  logic timer_awready;
  logic timer_wready;
  logic [1:0] timer_bresp;
  logic timer_bvalid;
  logic timer_arready;
  logic [31:0] timer_rdata;
  logic [1:0] timer_rresp;
  logic timer_rvalid;

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

  axi_lite_gpio_slave #(
    .ADDR_BYTES (GPIO_BYTES),
    .ADDR_BASE (GPIO_BASE)
  ) u_gpio (
    .clk_i (clk_i),
    .rst_i (rst_i),
    .gpio_i (gpio_i),
    .gpio_o (gpio_o),
    .s_axi_awaddr (m_axi_awaddr),
    .s_axi_awprot (m_axi_awprot),
    .s_axi_awvalid (gpio_awvalid),
    .s_axi_awready (gpio_awready),
    .s_axi_wdata (m_axi_wdata),
    .s_axi_wstrb (m_axi_wstrb),
    .s_axi_wvalid (gpio_wvalid),
    .s_axi_wready (gpio_wready),
    .s_axi_bresp (gpio_bresp),
    .s_axi_bvalid (gpio_bvalid),
    .s_axi_bready (m_axi_bready),
    .s_axi_araddr (m_axi_araddr),
    .s_axi_arprot (m_axi_arprot),
    .s_axi_arvalid (m_axi_arvalid && ar_gpio),
    .s_axi_arready (gpio_arready),
    .s_axi_rdata (gpio_rdata),
    .s_axi_rresp (gpio_rresp),
    .s_axi_rvalid (gpio_rvalid),
    .s_axi_rready (m_axi_rready)
  );

  axi_lite_uart_slave #(
    .ADDR_BYTES (UART_BYTES),
    .ADDR_BASE (UART_BASE)
  ) u_uart (
    .clk_i (clk_i),
    .rst_i (rst_i),
    .uart_rx_i (uart_rx_i),
    .uart_tx_o (uart_tx_o),
    .s_axi_awaddr (m_axi_awaddr),
    .s_axi_awprot (m_axi_awprot),
    .s_axi_awvalid (uart_awvalid),
    .s_axi_awready (uart_awready),
    .s_axi_wdata (m_axi_wdata),
    .s_axi_wstrb (m_axi_wstrb),
    .s_axi_wvalid (uart_wvalid),
    .s_axi_wready (uart_wready),
    .s_axi_bresp (uart_bresp),
    .s_axi_bvalid (uart_bvalid),
    .s_axi_bready (m_axi_bready),
    .s_axi_araddr (m_axi_araddr),
    .s_axi_arprot (m_axi_arprot),
    .s_axi_arvalid (m_axi_arvalid && ar_uart),
    .s_axi_arready (uart_arready),
    .s_axi_rdata (uart_rdata),
    .s_axi_rresp (uart_rresp),
    .s_axi_rvalid (uart_rvalid),
    .s_axi_rready (m_axi_rready)
  );

  axi_lite_timer_slave #(
    .ADDR_BYTES (TIMER_BYTES),
    .ADDR_BASE (TIMER_BASE)
  ) u_timer (
    .clk_i (clk_i),
    .rst_i (rst_i),
    .s_axi_awaddr (m_axi_awaddr),
    .s_axi_awprot (m_axi_awprot),
    .s_axi_awvalid (timer_awvalid),
    .s_axi_awready (timer_awready),
    .s_axi_wdata (m_axi_wdata),
    .s_axi_wstrb (m_axi_wstrb),
    .s_axi_wvalid (timer_wvalid),
    .s_axi_wready (timer_wready),
    .s_axi_bresp (timer_bresp),
    .s_axi_bvalid (timer_bvalid),
    .s_axi_bready (m_axi_bready),
    .s_axi_araddr (m_axi_araddr),
    .s_axi_arprot (m_axi_arprot),
    .s_axi_arvalid (m_axi_arvalid && ar_timer),
    .s_axi_arready (timer_arready),
    .s_axi_rdata (timer_rdata),
    .s_axi_rresp (timer_rresp),
    .s_axi_rvalid (timer_rvalid),
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
    .s_axi_arvalid (m_axi_arvalid && !ar_dmem && !ar_gpio && !ar_uart && !ar_timer),
    .s_axi_arready (err_arready),
    .s_axi_rdata (err_rdata),
    .s_axi_rresp (err_rresp),
    .s_axi_rvalid (err_rvalid),
    .s_axi_rready (m_axi_rready)
  );

  assign m_axi_awready =
      hit_dmem(m_axi_awaddr) ? dmem_awready :
          hit_gpio(m_axi_awaddr) ? gpio_awready :
              hit_uart(m_axi_awaddr) ? uart_awready :
                  hit_timer(m_axi_awaddr) ? timer_awready : err_awready;

  assign m_axi_wready = (route_w == WR_DMEM) ? dmem_wready :
      (route_w == WR_GPIO) ? gpio_wready :
          (route_w == WR_UART) ? uart_wready :
              (route_w == WR_TIMER) ? timer_wready : err_wready;

  assign m_axi_bvalid = dmem_bvalid || gpio_bvalid || uart_bvalid || timer_bvalid || err_bvalid;
  assign m_axi_bresp = dmem_bvalid ? dmem_bresp : gpio_bvalid ? gpio_bresp : uart_bvalid ? uart_bresp :
      timer_bvalid ? timer_bresp : err_bresp;

  assign m_axi_arready = ar_dmem ? dmem_arready : ar_gpio ? gpio_arready : ar_uart ? uart_arready :
      ar_timer ? timer_arready : err_arready;

  assign m_axi_rdata = dmem_rvalid ? dmem_rdata : gpio_rvalid ? gpio_rdata : uart_rvalid ? uart_rdata :
      timer_rvalid ? timer_rdata : err_rdata;
  assign m_axi_rresp = dmem_rvalid ? dmem_rresp : gpio_rvalid ? gpio_rresp : uart_rvalid ? uart_rresp :
      timer_rvalid ? timer_rresp : err_rresp;
  assign m_axi_rvalid = dmem_rvalid || gpio_rvalid || uart_rvalid || timer_rvalid || err_rvalid;

endmodule
