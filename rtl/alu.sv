`timescale 1ns / 1ps



module alu #(parameter width = 8) (
    input  logic             in_valid,
    input  logic [width-1:0] opnd_a,
    input  logic [width-1:0] opnd_b,
    input  logic             clk,
    input  logic             rst_n,
    input  logic [3:0]       opcode,
    input  logic             cin,
    output logic [width-1:0] y,
    output logic             out_valid,
    output logic             carry_flag,
    output logic             zero_flag,
    output logic             sign_flag,
    output logic             overflow_flag
);
  import alu_pkg::*;

  localparam int shw = $clog2(width);

  // internal signals
  logic [width-1:0] next_y, flag_src;
  logic             next_c, next_z, next_s, next_ov;
  logic [width:0]   sum;
  logic [shw-1:0]   shift_amt;

  assign shift_amt = opnd_b[shw-1:0];
    
    always_comb begin
    next_y =y;
    next_c = 1'b0;
    next_z = 1'b0;
    next_s = 1'b0;
    next_ov = 1'b0;
    sum= '0;
    
    unique case(opcode)
    
    OP_ADD: begin
  sum     = {1'b0, opnd_a} + {1'b0, opnd_b};
  next_y  = sum[width-1:0];
  next_c  = sum[width];
 next_ov = (~opnd_a[width-1] & ~opnd_b[width-1] &  next_y[width-1]) |
          ( opnd_a[width-1] &  opnd_b[width-1] & ~next_y[width-1]);
          end
    OP_ADC: begin
      sum     = {1'b0, opnd_a} + {1'b0, opnd_b} + cin;
      next_y  = sum[width-1:0];
      next_c  = sum[width];
     next_ov = (~opnd_a[width-1] & ~opnd_b[width-1] &  next_y[width-1]) |
          ( opnd_a[width-1] &  opnd_b[width-1] & ~next_y[width-1]);
    end
     OP_SUB: begin
      sum     = {1'b0, opnd_a} - {1'b0, opnd_b};
      next_y  = sum[width-1:0];
      next_c  = sum[width];                       // 1 = borrow
      next_ov = (~opnd_a[width-1] &  opnd_b[width-1] &  next_y[width-1]) |
          ( opnd_a[width-1] & ~opnd_b[width-1] & ~next_y[width-1]);
    end

    OP_SBB: begin
      sum     = {1'b0, opnd_a} - {1'b0, opnd_b} - cin;
      next_y  = sum[width-1:0];
      next_c  = sum[width];                       // 1 = borrow
      next_ov = (~opnd_a[width-1] &  opnd_b[width-1] &  next_y[width-1]) |
                ( opnd_a[width-1] & ~opnd_b[width-1] & ~next_y[width-1]);
    end
    OP_INC: begin
      sum     = {1'b0, opnd_a} + 1'b1;
      next_y  = sum[width-1:0];
      next_c  = sum[width];
      next_ov = ~opnd_a[width-1] & next_y[width-1];  // + to -
    end

    OP_DEC: begin
      sum     = {1'b0, opnd_a} - 1'b1;
      next_y  = sum[width-1:0];
      next_c  = sum[width];                          // borrow when a = 0
      next_ov = opnd_a[width-1] & ~next_y[width-1];  // - to +
    end

    OP_AND: next_y = opnd_a & opnd_b;
    OP_OR:  next_y = opnd_a | opnd_b;
    OP_XOR: next_y = opnd_a ^ opnd_b;
    OP_NOT: next_y = ~opnd_a;
    OP_SHL: begin
      next_y = opnd_a << shift_amt;
      next_c = (shift_amt != 0) ? opnd_a[width - shift_amt] : 1'b0;
    end

    OP_SHR: begin
      next_y = opnd_a >> shift_amt;
      next_c = (shift_amt != 0) ? opnd_a[shift_amt - 1] : 1'b0;
    end

    OP_SAR: begin
      next_y = $signed(opnd_a) >>> shift_amt;
      next_c = (shift_amt != 0) ? opnd_a[shift_amt - 1] : 1'b0;
    end

    // ---------- rotates (C = bit that wrapped around) ----------
    OP_ROL: begin
      next_y = (opnd_a << shift_amt) | (opnd_a >> (width - shift_amt));
      next_c = (shift_amt != 0) ? next_y[0] : 1'b0;
    end

    OP_ROR: begin
      next_y = (opnd_a >> shift_amt) | (opnd_a << (width - shift_amt));
      next_c = (shift_amt != 0) ? next_y[width-1] : 1'b0;
    end

    // ---------- compare: flags from a - b, y holds ----------
    OP_CMP: begin
      sum     = {1'b0, opnd_a} - {1'b0, opnd_b};
      next_c  = sum[width];
      next_ov = (opnd_a[width-1] != opnd_b[width-1]) &&
                (sum[width-1] != opnd_a[width-1]);
    end
  endcase
   // ---------- Z and N, shared by all ops ----------
  flag_src = (opcode == OP_CMP) ? sum[width-1:0] : next_y;
  next_z   = (flag_src == '0);
  next_s   = flag_src[width-1];
end
   
    
    
    always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    y             <= '0;
    carry_flag    <= 1'b0;
    zero_flag     <= 1'b0;
    sign_flag     <= 1'b0;
    overflow_flag <= 1'b0;
    out_valid     <= 1'b0;
  end
  else begin
    out_valid <= in_valid;          // every cycle

    if (in_valid) begin             // load only on a real operation
      y             <= next_y;
      carry_flag    <= next_c;
      zero_flag     <= next_z;
      sign_flag     <= next_s;
      overflow_flag <= next_ov;
    end
  end
end
    
endmodule
