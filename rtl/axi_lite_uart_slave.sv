module axi_lite_uart_slave #(
  parameter int ADDR_BYTES = 4096,
  parameter logic [31:0] ADDR_BASE = 32'h1000_1000
) (
  input logic clk_i,
  input logic rst_i,

  input logic uart_rx_i,
  output logic uart_tx_o,

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
  localparam logic [31:0] OFF_STAT = 32'h0000_0004;
  localparam logic [31:0] OFF_DIV = 32'h0000_0008;

  function automatic logic addr_in_range(input logic [31:0] byte_addr);
    return byte_addr >= ADDR_BASE && byte_addr < (ADDR_BASE + ADDR_BYTES);
  endfunction

  function automatic logic addr_word_ok(input logic [31:0] byte_addr);
    return addr_in_range(byte_addr) && addr_in_range(byte_addr + 32'd3);
  endfunction

  function automatic logic [31:0] reg_off(input logic [31:0] axaddr);
    return axaddr - ADDR_BASE;
  endfunction

  // Baud: DIV = clock cycles per serial bit (minimum 8), drives TX/RX bit counters
  logic [31:0] div_r;
  wire [31:0] div_safe_w = (div_r < 32'd8) ? 32'd8 : div_r;

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
  logic [31:0] rd_ar_off_r;

  wire r_done_w = s_axi_rready && rvalid_r;
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

  // Write data: apply WSTRB to DIV
  integer kw;
  always_ff @(posedge clk_i) begin
    if (rst_i)
      div_r <= 32'd100;
    else if (w_fire && addr_word_ok(wr_use_addr_w) && (reg_off(wr_use_addr_w) == OFF_DIV)) begin
      for (kw = 0; kw < 4; kw++)
        if (s_axi_wstrb[kw])
          div_r[8*kw+:8] <= s_axi_wdata[8*kw+:8];
    end
  end

  wire tx_data_wr_w =
      w_fire && addr_word_ok(wr_use_addr_w) && (reg_off(wr_use_addr_w) == OFF_DATA) && s_axi_wstrb[0];

  // TX hold: enqueue byte from DATA write (low byte via WSTRB[0]), duplicate while full -> SLVERR on B
  logic [7:0] tx_hold_r;
  logic tx_hold_valid_r;
  logic bresp_err_r;

  // UART TX: 8N1 bit engine (idle high, start 0, 8 data LSB first, stop 1)
  typedef enum logic [1:0] {
    TX_ST_IDLE,
    TX_ST_START,
    TX_ST_DATA,
    TX_ST_STOP
  } tx_st_t;

  tx_st_t tx_st_r;
  logic [31:0] tx_bc_r;
  logic [7:0] tx_sh_r;
  logic [2:0] tx_bi_r;

  wire tx_tick_w = (tx_bc_r >= div_safe_w - 32'd1);
  wire tx_consume_hold_w = (tx_st_r == TX_ST_IDLE) && tx_hold_valid_r;
  wire tx_dup_w = tx_data_wr_w && tx_hold_valid_r && !(tx_consume_hold_w && tx_data_wr_w);

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      tx_hold_r <= 8'b0;
      tx_hold_valid_r <= 1'b0;
    end else begin
      if (tx_consume_hold_w && tx_data_wr_w) begin
        tx_hold_r <= s_axi_wdata[7:0];
        tx_hold_valid_r <= 1'b1;
      end else if (tx_consume_hold_w)
        tx_hold_valid_r <= 1'b0;
      else if (tx_data_wr_w) begin
        if (!tx_hold_valid_r) begin
          tx_hold_r <= s_axi_wdata[7:0];
          tx_hold_valid_r <= 1'b1;
        end
      end
    end
  end

  // TX serializer: drives uart_tx_o from tx_sh_r / tx_bi_r each bit period
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      tx_st_r <= TX_ST_IDLE;
      tx_bc_r <= 32'b0;
      tx_sh_r <= 8'b0;
      tx_bi_r <= 3'b0;
      uart_tx_o <= 1'b1;
    end else begin
      case (tx_st_r)
        TX_ST_IDLE: begin
          uart_tx_o <= 1'b1;
          tx_bc_r <= 32'b0;
          if (tx_hold_valid_r) begin
            if (tx_data_wr_w)
              tx_sh_r <= s_axi_wdata[7:0];
            else
              tx_sh_r <= tx_hold_r;
            tx_st_r <= TX_ST_START;
            uart_tx_o <= 1'b0;
            tx_bc_r <= 32'b0;
          end
        end
        TX_ST_START: begin
          uart_tx_o <= 1'b0;
          if (tx_tick_w) begin
            tx_bc_r <= 32'b0;
            tx_bi_r <= 3'b0;
            tx_st_r <= TX_ST_DATA;
            uart_tx_o <= tx_sh_r[0];
          end else
            tx_bc_r <= tx_bc_r + 32'd1;
        end
        TX_ST_DATA: begin
          uart_tx_o <= tx_sh_r[tx_bi_r];
          if (tx_tick_w) begin
            tx_bc_r <= 32'b0;
            if (tx_bi_r == 3'd7) begin
              tx_st_r <= TX_ST_STOP;
              uart_tx_o <= 1'b1;
            end else
              tx_bi_r <= tx_bi_r + 3'd1;
          end else
            tx_bc_r <= tx_bc_r + 32'd1;
        end
        TX_ST_STOP: begin
          uart_tx_o <= 1'b1;
          if (tx_tick_w) begin
            tx_bc_r <= 32'b0;
            tx_st_r <= TX_ST_IDLE;
          end else
            tx_bc_r <= tx_bc_r + 32'd1;
        end
      endcase
    end
  end

  // RX: sync asynchronous uart_rx_i
  logic rx_meta_r;
  logic rx_sync_r;
  logic rx_prev_r;

  always_ff @(posedge clk_i) begin
    rx_meta_r <= uart_rx_i;
    rx_sync_r <= rx_meta_r;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i)
      rx_prev_r <= 1'b1;
    else
      rx_prev_r <= rx_sync_r;
  end

  wire rx_negedge_w = rx_prev_r && !rx_sync_r;

  // UART RX: 8N1 (half bit align, sample data, check stop)
  typedef enum logic [2:0] {
    RX_ST_IDLE,
    RX_ST_HALF,
    RX_ST_DATA,
    RX_ST_STOP
  } rx_st_t;

  rx_st_t rx_st_r;
  logic [31:0] rx_bc_r;
  logic [7:0] rx_sh_r;
  logic [2:0] rx_bi_r;
  logic [7:0] rx_data_r;
  logic rx_have_r;
  logic rx_overrun_r;

  wire rx_tick_w = (rx_bc_r >= div_safe_w - 32'd1);
  wire [31:0] rx_half_w = (div_safe_w >> 1) - 32'd1;
  wire rx_half_tick_w = (rx_bc_r >= rx_half_w);

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      rx_st_r <= RX_ST_IDLE;
      rx_bc_r <= 32'b0;
      rx_sh_r <= 8'b0;
      rx_bi_r <= 3'b0;
      rx_data_r <= 8'b0;
      rx_have_r <= 1'b0;
      rx_overrun_r <= 1'b0;
    end else begin
      if (r_done_w && (rd_ar_off_r == OFF_DATA) && rx_have_r)
        rx_have_r <= 1'b0;

      case (rx_st_r)
        RX_ST_IDLE: begin
          rx_bc_r <= 32'b0;
          if (rx_negedge_w) begin
            rx_st_r <= RX_ST_HALF;
            rx_bc_r <= 32'b0;
          end
        end
        RX_ST_HALF: begin
          if (rx_half_tick_w) begin
            if (!rx_sync_r) begin
              rx_bc_r <= 32'b0;
              rx_bi_r <= 3'b0;
              rx_st_r <= RX_ST_DATA;
            end else
              rx_st_r <= RX_ST_IDLE;
          end else
            rx_bc_r <= rx_bc_r + 32'd1;
        end
        RX_ST_DATA: begin
          if (rx_tick_w) begin
            rx_sh_r[rx_bi_r] <= rx_sync_r;
            rx_bc_r <= 32'b0;
            if (rx_bi_r == 3'd7) begin
              rx_st_r <= RX_ST_STOP;
            end else
              rx_bi_r <= rx_bi_r + 3'd1;
          end else
            rx_bc_r <= rx_bc_r + 32'd1;
        end
        RX_ST_STOP: begin
          if (rx_tick_w) begin
            if (rx_sync_r) begin
              if (rx_have_r)
                rx_overrun_r <= 1'b1;
              else begin
                rx_data_r <= rx_sh_r;
                rx_have_r <= 1'b1;
              end
            end
            rx_st_r <= RX_ST_IDLE;
            rx_bc_r <= 32'b0;
          end else
            rx_bc_r <= rx_bc_r + 32'd1;
        end
      endcase
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

  // Write response: OKAY or SLVERR when DATA write overflows TX hold (see tx_dup_w)
  always_ff @(posedge clk_i) begin
    if (rst_i)
      bresp_err_r <= 1'b0;
    else if (wr_state_r == WR_B && s_axi_bready && s_axi_bvalid)
      bresp_err_r <= 1'b0;
    else if (w_fire && tx_dup_w)
      bresp_err_r <= 1'b1;
  end

  assign s_axi_bresp = (wr_state_r == WR_B && bresp_err_r) ? axi4_lite_pkg::RESP_SLVERR : axi4_lite_pkg::RESP_OKAY;
  assign s_axi_bvalid = wr_state_r == WR_B;

  // Read channel: AR handshake, then RDATA (blocked while write response pending)
  wire ar_fire = s_axi_arvalid && s_axi_arready;

  assign s_axi_arready = (rd_state_r == RD_IDLE) && !wr_busy_w && !s_axi_bvalid;

  // Last accepted read byte offset (DATA read clears RXNE when rx_have_r)
  always_ff @(posedge clk_i) begin
    if (rst_i)
      rd_ar_off_r <= 32'hFFFF_FFFF;
    else if (ar_fire && addr_word_ok(s_axi_araddr))
      rd_ar_off_r <= reg_off(s_axi_araddr);
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
          if (r_done_w)
            rd_state_r <= RD_IDLE;
      endcase
    end
  end

  // Pulse RVALID after accepted AR
  always_ff @(posedge clk_i) begin
    if (rst_i)
      rvalid_r <= 1'b0;
    else begin
      if (r_done_w)
        rvalid_r <= 1'b0;
      else if (ar_fire && addr_word_ok(s_axi_araddr))
        rvalid_r <= 1'b1;
    end
  end

  wire tx_busy_w = (tx_st_r != TX_ST_IDLE);
  wire txe_w = !tx_hold_valid_r;
  wire rxne_w = rx_have_r;

  // Per register read
  function automatic logic [31:0] read_reg(input logic [31:0] axaddr);
    logic [31:0] off;
    off = reg_off(axaddr);
    if (off == OFF_STAT)
      return {26'b0, rx_overrun_r, tx_busy_w, txe_w, rxne_w};
    if (off == OFF_DIV)
      return div_r;
    if (off == OFF_DATA)
      return {24'b0, rxne_w ? rx_data_r : 8'b0};
    return 32'b0;
  endfunction

  // Capture RDATA at AR
  always_ff @(posedge clk_i) begin
    if (ar_fire && addr_word_ok(s_axi_araddr))
      rdata_hold_r <= read_reg(s_axi_araddr);
  end

  // Outputs to master
  assign s_axi_rdata = rdata_hold_r;
  assign s_axi_rresp = axi4_lite_pkg::RESP_OKAY;
  assign s_axi_rvalid = rvalid_r;

endmodule
