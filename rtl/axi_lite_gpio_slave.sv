module axi_lite_gpio_slave #(
  parameter int ADDR_BYTES = 4096,
  parameter logic [31:0] ADDR_BASE = 32'h1000_0000
) (
  input logic clk_i,
  input logic rst_i,

  input logic [31:0] gpio_i,
  output logic [31:0] gpio_o,

  input logic [31:0] s_axi_awaddr,
  input logic [2:0] s_axi_awprot,
  input logic s_axi_awvalid,
  output logic s_axi_awready,

  input logic [31:0] s_axi_wdata,
  input logic [3:0] s_axi_wstrb,
  input logic s_axi_wvalid,
  output logic s_axi_wready,

  output logic [1:0] s_axi_bresp,
  output logic s_axi_bvalid,
  input logic s_axi_bready,

  input logic [31:0] s_axi_araddr,
  input logic [2:0] s_axi_arprot,
  input logic s_axi_arvalid,
  output logic s_axi_arready,

  output logic [31:0] s_axi_rdata,
  output logic [1:0] s_axi_rresp,
  output logic s_axi_rvalid,
  input logic s_axi_rready
);

  // Register map
  localparam logic [31:0] OFF_DATA = 32'h0000_0000;
  localparam logic [31:0] OFF_DIR = 32'h0000_0004;

  function automatic logic addr_in_range(input logic [31:0] byte_addr);
    return byte_addr >= ADDR_BASE && byte_addr < (ADDR_BASE + ADDR_BYTES);
  endfunction

  function automatic logic addr_word_ok(input logic [31:0] byte_addr);
    return addr_in_range(byte_addr) && addr_in_range(byte_addr + 32'd3);
  endfunction

  // Sync inputs
  logic [31:0] data_out_r;
  logic [31:0] dir_r;
  logic [31:0] gpio_i_sync_r;

  always_ff @(posedge clk_i) begin
    gpio_i_sync_r <= gpio_i;
  end

  assign gpio_o = data_out_r & dir_r;

  // Write channel: AW then W (or same cycle)
  typedef enum logic [1:0] {
    WR_IDLE,
    WR_AW_OK,
    WR_B
  } wr_state_t;

  wr_state_t wr_state_r;
  logic [31:0] wr_addr_r;

  typedef enum logic [1:0] {
    RD_IDLE,
    RD_WAIT_R
  } rd_state_t;

  rd_state_t rd_state_r;
  logic rvalid_r;
  logic [31:0] rdata_hold_r;

  wire wr_busy_w = wr_state_r != WR_IDLE;

  assign s_axi_awready = (wr_state_r == WR_IDLE) && addr_word_ok(s_axi_awaddr);
  assign s_axi_wready = ((wr_state_r == WR_AW_OK) && addr_word_ok(wr_addr_r)) || ((wr_state_r == WR_IDLE) && addr_word_ok(s_axi_awaddr) && s_axi_awvalid && s_axi_wvalid);

  wire aw_fire = s_axi_awvalid && s_axi_awready;
  wire w_fire = s_axi_wvalid && s_axi_wready;
  wire wr_same_cycle_w = (wr_state_r == WR_IDLE) && aw_fire && w_fire;

  logic [31:0] wr_use_addr_w;
  assign wr_use_addr_w = wr_same_cycle_w ? s_axi_awaddr : wr_addr_r;

  always_ff @(posedge clk_i) begin
    if (aw_fire)
      wr_addr_r <= s_axi_awaddr;
  end

  // Write data: apply WSTRB to DATA or DIR registers
  function automatic logic [31:0] reg_offset(input logic [31:0] axaddr);
    return axaddr - ADDR_BASE;
  endfunction

  integer k;
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      data_out_r <= 32'b0;
      dir_r <= 32'b0;
    end else if (w_fire && addr_word_ok(wr_use_addr_w)) begin
      if (reg_offset(wr_use_addr_w) == OFF_DATA) begin
        for (k = 0; k < 4; k++)
          if (s_axi_wstrb[k])
            data_out_r[8*k+:8] <= s_axi_wdata[8*k+:8];
      end else if (reg_offset(wr_use_addr_w) == OFF_DIR) begin
        for (k = 0; k < 4; k++)
          if (s_axi_wstrb[k])
            dir_r[8*k+:8] <= s_axi_wdata[8*k+:8];
      end
    end
  end

  // Write FSM
  always_ff @(posedge clk_i) begin
    if (rst_i)
      wr_state_r <= WR_IDLE;
    else begin
      case (wr_state_r)
        WR_IDLE:
          if (wr_same_cycle_w)
            wr_state_r <= WR_B;
          else if (aw_fire)
            wr_state_r <= WR_AW_OK;
        WR_AW_OK:
          if (w_fire)
            wr_state_r <= WR_B;
        WR_B:
          if (s_axi_bready && s_axi_bvalid)
            wr_state_r <= WR_IDLE;
      endcase
    end
  end

  assign s_axi_bresp = axi4_lite_pkg::RESP_OKAY;
  assign s_axi_bvalid = wr_state_r == WR_B;

  // Read channel: AR handshake, then RDATA (blocked while write response pending)
  wire ar_fire = s_axi_arvalid && s_axi_arready;

  assign s_axi_arready = (rd_state_r == RD_IDLE) && !wr_busy_w && !s_axi_bvalid;

  // Read data: per-register value (DATA merges pads vs latched outputs)
  function automatic logic [31:0] read_reg(input logic [31:0] axaddr);
    logic [31:0] off;
    off = reg_offset(axaddr);
    if (off == OFF_DATA)
      return (gpio_i_sync_r & ~dir_r) | (data_out_r & dir_r);
    if (off == OFF_DIR)
      return dir_r;
    return 32'b0;
  endfunction

  always_ff @(posedge clk_i) begin
    if (ar_fire && addr_word_ok(s_axi_araddr))
      rdata_hold_r <= read_reg(s_axi_araddr);
  end

  // Read FSM
  always_ff @(posedge clk_i) begin
    if (rst_i)
      rd_state_r <= RD_IDLE;
    else begin
      case (rd_state_r)
        RD_IDLE:
          if (ar_fire && addr_word_ok(s_axi_araddr))
            rd_state_r <= RD_WAIT_R;
        RD_WAIT_R:
          if (s_axi_rready && rvalid_r)
            rd_state_r <= RD_IDLE;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_i)
      rvalid_r <= 1'b0;
    else begin
      if (s_axi_rready && rvalid_r)
        rvalid_r <= 1'b0;
      else if (ar_fire && addr_word_ok(s_axi_araddr))
        rvalid_r <= 1'b1;
    end
  end

  // Read data outputs
  assign s_axi_rdata = rdata_hold_r;
  assign s_axi_rresp = axi4_lite_pkg::RESP_OKAY;
  assign s_axi_rvalid = rvalid_r;

endmodule
