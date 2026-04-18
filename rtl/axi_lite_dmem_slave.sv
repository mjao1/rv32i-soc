module axi_lite_dmem_slave #(
  parameter int MEM_BYTES = 4096,
  parameter logic [31:0] ADDR_BASE = 32'h0000_0000
) (
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

  logic [7:0] mem_r[0:MEM_BYTES-1];

  integer init_i;
  initial begin
    for (init_i = 0; init_i < MEM_BYTES; init_i++)
      mem_r[init_i] = 8'h00;
  end

  function automatic logic [31:0] phys(input logic [31:0] byte_addr);
    return byte_addr - ADDR_BASE;
  endfunction

  function automatic logic addr_word_ok(input logic [31:0] byte_addr);
    logic [31:0] aligned;
    logic [31:0] p;
    aligned = byte_addr & 32'hFFFF_FFFC;
    p = phys(aligned);
    return byte_addr >= ADDR_BASE && (p + 32'd4 <= MEM_BYTES);
  endfunction

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
  assign s_axi_wready =
      ((wr_state_r == WR_AW_OK) && addr_word_ok(wr_addr_r)) ||
      ((wr_state_r == WR_IDLE) && addr_word_ok(s_axi_awaddr) && s_axi_awvalid && s_axi_wvalid);

  wire aw_fire = s_axi_awvalid && s_axi_awready;
  wire w_fire = s_axi_wvalid && s_axi_wready;
  wire wr_same_cycle_w = (wr_state_r == WR_IDLE) && aw_fire && w_fire;

  logic [31:0] wr_use_addr_w;
  assign wr_use_addr_w = wr_same_cycle_w ? s_axi_awaddr : wr_addr_r;

  always_ff @(posedge clk_i) begin
    if (aw_fire)
      wr_addr_r <= s_axi_awaddr;
  end

  integer k;
  always_ff @(posedge clk_i) begin
    if (w_fire && addr_word_ok(wr_use_addr_w)) begin
      for (k = 0; k < 4; k++) begin
        if (s_axi_wstrb[k])
          mem_r[phys(wr_use_addr_w & 32'hFFFF_FFFC) + k] <= s_axi_wdata[8*k+:8];
      end
    end
  end

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

  wire ar_fire = s_axi_arvalid && s_axi_arready;

  assign s_axi_arready = (rd_state_r == RD_IDLE) && !wr_busy_w && !s_axi_bvalid;

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
    if (ar_fire && addr_word_ok(s_axi_araddr))
      rdata_hold_r <= {
        mem_r[phys(s_axi_araddr & 32'hFFFF_FFFC)+3],
        mem_r[phys(s_axi_araddr & 32'hFFFF_FFFC)+2],
        mem_r[phys(s_axi_araddr & 32'hFFFF_FFFC)+1],
        mem_r[phys(s_axi_araddr & 32'hFFFF_FFFC)]
      };
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

  assign s_axi_rdata = rdata_hold_r;
  assign s_axi_rresp = axi4_lite_pkg::RESP_OKAY;
  assign s_axi_rvalid = rvalid_r;

endmodule
