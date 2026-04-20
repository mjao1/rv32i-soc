// AXI4-Lite master: single-flight load/store unit (LSU)
// Drives one txn at a time from EX/MEM snapshot
module dmem_axi_lite_master (
  input logic clk_i,
  input logic rst_i,

  // EX/MEM snapshot
  input logic [31:0] ex_mem_addr_i,
  input logic ex_mem_mem_write_i,
  input logic ex_mem_reg_write_i,
  input logic [1:0] ex_mem_result_src_i,
  input logic [2:0] ex_mem_funct3_i,
  input logic [31:0] ex_mem_wdata_i,
  input logic [4:0] ex_mem_rd_i,

  // Back to CPU
  output logic stall_o,
  output logic load_rsp_valid_o,
  output logic [4:0] load_rd_o,
  output logic [31:0] load_data_o,

  // AXI4-Lite master (to interconnect)
  output logic [31:0] m_axi_araddr,
  output logic [2:0] m_axi_arprot,
  output logic m_axi_arvalid,
  input logic m_axi_arready,

  input logic [31:0] m_axi_rdata,
  input logic [1:0] m_axi_rresp,
  input logic m_axi_rvalid,
  output logic m_axi_rready,

  output logic [31:0] m_axi_awaddr,
  output logic [2:0] m_axi_awprot,
  output logic m_axi_awvalid,
  input logic m_axi_awready,

  output logic [31:0] m_axi_wdata,
  output logic [3:0] m_axi_wstrb,
  output logic m_axi_wvalid,
  input logic m_axi_wready,

  input logic [1:0] m_axi_bresp,
  input logic m_axi_bvalid,
  output logic m_axi_bready
);

  // Decode load/store from EX/MEM
  wire is_load_w = ex_mem_reg_write_i && (ex_mem_result_src_i == rv32i_pkg::RESULT_MEM);
  wire is_store_w = ex_mem_mem_write_i;
  wire need_mem_w = is_load_w || is_store_w;

  // FSM: IDLE latches txn
  // load path AR->R->RESP
  // store path AW+W->B
  typedef enum logic [2:0] {
    ST_IDLE,
    ST_AR,
    ST_R,
    ST_RESP,
    ST_AW_W,
    ST_B
  } state_t;

  state_t state_r;
  state_t state_prev_r;
  logic [31:0] rdata_word_r;
  logic [31:0] load_data_hold_r;

  logic [31:0] latched_addr_r;
  logic [2:0] latched_funct3_r;
  logic [31:0] latched_wdata_r;
  logic [4:0] latched_rd_r;

  // Word read LB/LH/LW/LBU/LHU (matches data_memory.sv)
  function automatic logic [31:0] fmt_load(
    input logic [31:0] word,
    input logic [2:0] funct3,
    input logic [31:0] byte_addr
  );
    logic [1:0] lo;
    begin
      lo = byte_addr[1:0];
      case (funct3)
        3'b000: begin
          case (lo)
            2'b00: fmt_load = {{24{word[7]}}, word[7:0]};
            2'b01: fmt_load = {{24{word[15]}}, word[15:8]};
            2'b10: fmt_load = {{24{word[23]}}, word[23:16]};
            default: fmt_load = {{24{word[31]}}, word[31:24]};
          endcase
        end
        3'b001: fmt_load = byte_addr[1] ? {{16{word[31]}}, word[31:16]} : {{16{word[15]}}, word[15:0]};
        3'b010: fmt_load = word;
        3'b100: begin
          case (lo)
            2'b00: fmt_load = {24'b0, word[7:0]};
            2'b01: fmt_load = {24'b0, word[15:8]};
            2'b10: fmt_load = {24'b0, word[23:16]};
            default: fmt_load = {24'b0, word[31:24]};
          endcase
        end
        3'b101: fmt_load = byte_addr[1] ? {16'b0, word[31:16]} : {16'b0, word[15:0]};
        default: fmt_load = 32'b0;
      endcase
    end
  endfunction

  // SB/SH/SW select wstrb
  function automatic logic [3:0] store_strb(
    input logic [2:0] funct3,
    input logic [31:0] byte_addr
  );
    begin
      case (funct3)
        3'b000: begin
          case (byte_addr[1:0])
            2'b00: store_strb = 4'b0001;
            2'b01: store_strb = 4'b0010;
            2'b10: store_strb = 4'b0100;
            default: store_strb = 4'b1000;
          endcase
        end
        3'b001: store_strb = byte_addr[1] ? 4'b1100 : 4'b0011;
        3'b010: store_strb = 4'b1111;
        default: store_strb = 4'b0000;
      endcase
    end
  endfunction

  // SB/SH store data: replicate the value across all byte lanes so the data
  function automatic logic [31:0] fmt_store(
    input logic [31:0] data,
    input logic [2:0] funct3
  );
    case (funct3)
      3'b000: fmt_store = {4{data[7:0]}};
      3'b001: fmt_store = {2{data[15:0]}};
      3'b010: fmt_store = data;
      default: fmt_store = data;
    endcase
  endfunction

  // avoids combinational error when FSM returns to IDLE
  assign load_data_o = load_data_hold_r;

  // Stall
  wire suppress_idle_need_w = (state_prev_r == ST_B) || (state_prev_r == ST_RESP);

  assign stall_o = (state_r != ST_IDLE) || ((state_r == ST_IDLE) && need_mem_w && !suppress_idle_need_w);

  assign load_rsp_valid_o = (state_r == ST_RESP);
  assign load_rd_o = latched_rd_r;

  wire [31:0] word_addr_lat_w = latched_addr_r & 32'hFFFF_FFFC;

  // Read address channel
  assign m_axi_arprot = 3'b000;
  assign m_axi_awprot = 3'b000;
  assign m_axi_araddr = word_addr_lat_w;
  assign m_axi_awaddr = word_addr_lat_w;
  assign m_axi_wdata = fmt_store(latched_wdata_r, latched_funct3_r);
  assign m_axi_wstrb = store_strb(latched_funct3_r, latched_addr_r);

  // Handshakes
  wire ar_fire_w = m_axi_arvalid && m_axi_arready;
  wire r_fire_w = m_axi_rvalid && m_axi_rready;
  wire aw_fire_w = m_axi_awvalid && m_axi_awready;
  wire w_fire_w = m_axi_wvalid && m_axi_wready;
  wire b_fire_w = m_axi_bvalid && m_axi_bready;

  // Read channel
  assign m_axi_arvalid = (state_r == ST_AR);
  assign m_axi_rready = (state_r == ST_R);

  // Write channel (AW+W same state; B response)
  assign m_axi_awvalid = (state_r == ST_AW_W);
  assign m_axi_wvalid = (state_r == ST_AW_W);
  assign m_axi_bready = (state_r == ST_B);

  // State, latches, rdata
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state_r <= ST_IDLE;
      state_prev_r <= ST_IDLE;
      rdata_word_r <= 32'b0;
      load_data_hold_r <= 32'b0;
      latched_addr_r <= 32'b0;
      latched_funct3_r <= 3'b0;
      latched_wdata_r <= 32'b0;
      latched_rd_r <= 5'b0;
    end else begin
      state_prev_r <= state_r;
      case (state_r)
        ST_IDLE:
          if (need_mem_w && !suppress_idle_need_w) begin
            latched_addr_r <= ex_mem_addr_i;
            latched_funct3_r <= ex_mem_funct3_i;
            latched_wdata_r <= ex_mem_wdata_i;
            latched_rd_r <= ex_mem_rd_i;
            if (is_load_w)
              state_r <= ST_AR;
            else
              state_r <= ST_AW_W;
          end
        ST_AR:
          if (ar_fire_w)
            state_r <= ST_R;
        ST_R:
          if (r_fire_w) begin
            rdata_word_r <= m_axi_rdata;
            load_data_hold_r <= fmt_load(m_axi_rdata, latched_funct3_r, latched_addr_r);
            state_r <= ST_RESP;
          end
        ST_RESP:
          state_r <= ST_IDLE;
        ST_AW_W:
          if (aw_fire_w && w_fire_w)
            state_r <= ST_B;
        ST_B:
          if (b_fire_w)
            state_r <= ST_IDLE;
        default:
          state_r <= ST_IDLE;
      endcase
    end
  end

endmodule
