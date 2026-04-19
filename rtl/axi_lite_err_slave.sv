module axi_lite_err_slave (
  input logic clk_i,
  input logic rst_i,

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

  // Write channel: AW then W (or same cycle)
  typedef enum logic [1:0] {
    WR_IDLE,
    WR_AW_OK,
    WR_B
  } wr_state_t;

  wr_state_t wr_state_r;

  typedef enum logic [1:0] {
    RD_IDLE,
    RD_WAIT_R
  } rd_state_t;

  rd_state_t rd_state_r;
  logic rvalid_r;

  wire wr_busy_w = wr_state_r != WR_IDLE;

  assign s_axi_awready = wr_state_r == WR_IDLE;
  assign s_axi_wready =
      (wr_state_r == WR_AW_OK) ||
      ((wr_state_r == WR_IDLE) && s_axi_awvalid && s_axi_wvalid);

  wire aw_fire = s_axi_awvalid && s_axi_awready;
  wire w_fire = s_axi_wvalid && s_axi_wready;
  wire wr_same_cycle_w = (wr_state_r == WR_IDLE) && aw_fire && w_fire;

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

  assign s_axi_bresp = axi4_lite_pkg::RESP_SLVERR;
  assign s_axi_bvalid = wr_state_r == WR_B;

  // Read channel: AR handshake, then RDATA (blocked while write response pending)
  wire ar_fire = s_axi_arvalid && s_axi_arready;

  assign s_axi_arready = (rd_state_r == RD_IDLE) && !wr_busy_w && !s_axi_bvalid;

  // Read FSM
  always_ff @(posedge clk_i) begin
    if (rst_i)
      rd_state_r <= RD_IDLE;
    else begin
      case (rd_state_r)
        RD_IDLE:
          if (ar_fire)
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
      else if (ar_fire)
        rvalid_r <= 1'b1;
    end
  end

  // Outputs to master
  assign s_axi_rdata = 32'b0; // always error response on read
  assign s_axi_rresp = axi4_lite_pkg::RESP_SLVERR;
  assign s_axi_rvalid = rvalid_r;

endmodule
