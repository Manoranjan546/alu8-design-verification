`timescale 1ns / 1ps

// Wrapper used only for timing measurement in Vivado.
// Registers the ALU's inputs so every timed path runs flip-flop to flip-flop.
module alu_top #(parameter width = 8) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             in_valid,
    input  logic [width-1:0] opnd_a,
    input  logic [width-1:0] opnd_b,
    input  logic [3:0]       opcode,
    input  logic             cin,
    output logic [width-1:0] y,
    output logic             out_valid,
    output logic             carry_flag,
    output logic             zero_flag,
    output logic             sign_flag,
    output logic             overflow_flag
);

  // registered copies of the inputs
  logic             in_valid_r, cin_r;
  logic [width-1:0] opnd_a_r, opnd_b_r;
  logic [3:0]       opcode_r;

  // control signal: needs a reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) in_valid_r <= 1'b0;
    else        in_valid_r <= in_valid;
  end

  // data signals: no reset needed
  always_ff @(posedge clk) begin
    opnd_a_r <= opnd_a;
    opnd_b_r <= opnd_b;
    opcode_r <= opcode;
    cin_r    <= cin;
  end

  // the unchanged ALU, fed from the registers
  alu #(.width(width)) u_alu (
    .clk           (clk),
    .rst_n         (rst_n),
    .in_valid      (in_valid_r),
    .opnd_a        (opnd_a_r),
    .opnd_b        (opnd_b_r),
    .opcode        (opcode_r),
    .cin           (cin_r),
    .y             (y),
    .out_valid     (out_valid),
    .carry_flag    (carry_flag),
    .zero_flag     (zero_flag),
    .sign_flag     (sign_flag),
    .overflow_flag (overflow_flag)
  );

endmodule
