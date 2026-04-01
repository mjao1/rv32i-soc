package rv32i_pkg;

  // Opcodes
  localparam logic [6:0] OP_LUI    = 7'b0110111;
  localparam logic [6:0] OP_AUIPC  = 7'b0010111;
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_ALU_I  = 7'b0010011;
  localparam logic [6:0] OP_ALU_R  = 7'b0110011;
  localparam logic [6:0] OP_FENCE  = 7'b0001111;
  localparam logic [6:0] OP_SYSTEM = 7'b1110011;

  // ALU operations
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_AND  = 4'b0010,
    ALU_OR   = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SLT  = 4'b0101,
    ALU_SLTU = 4'b0110,
    ALU_SLL  = 4'b0111,
    ALU_SRL  = 4'b1000,
    ALU_SRA  = 4'b1001
  } alu_op_t;

  // Branch operations
  typedef enum logic [2:0] {
    BRANCH_BEQ  = 3'b000,
    BRANCH_BNE  = 3'b001,
    BRANCH_JAL  = 3'b010,
    BRANCH_BLT  = 3'b100,
    BRANCH_BGE  = 3'b101,
    BRANCH_BLTU = 3'b110,
    BRANCH_BGEU = 3'b111
  } branch_op_t;

  // Result mux select
  typedef enum logic [1:0] {
    RESULT_ALU = 2'b00,
    RESULT_PC4 = 2'b01,
    RESULT_MEM = 2'b10
  } result_src_t;

endpackage
