package alu_pkg;
  typedef enum logic [3:0] {
    OP_ADD = 4'b0000,
    OP_ADC = 4'b0001,
    OP_SUB = 4'b0010,
    OP_SBB = 4'b0011,
    OP_INC = 4'b0100,
    OP_DEC = 4'b0101,
    OP_AND = 4'b0110,
    OP_OR  = 4'b0111,
    OP_XOR = 4'b1000,
    OP_NOT = 4'b1001,
    OP_SHL = 4'b1010,
    OP_SHR = 4'b1011,
    OP_SAR = 4'b1100,
    OP_ROL = 4'b1101,
    OP_ROR = 4'b1110,
    OP_CMP = 4'b1111
  } opcode_t;
endpackage
