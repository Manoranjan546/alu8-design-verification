`timescale 1ns / 1ps

module tb_alu #(parameter width = 8);
  import alu_pkg::*;

  // ---------------- signals ----------------
  // driven by the testbench (DUT inputs)
  logic             in_valid, clk, rst_n, cin;
  logic [3:0]       opcode;
  logic [width-1:0] opnd_a, opnd_b;

  // driven by the DUT (DUT outputs)
  logic             out_valid, carry_flag, zero_flag, sign_flag, overflow_flag;
  logic [width-1:0] y;

  // testbench bookkeeping
  int pass_count = 0, fail_count = 0;

  // ---------------- DUT ----------------
  alu #(.width(width)) dut (
    .in_valid      (in_valid),
    .opnd_a        (opnd_a),
    .opnd_b        (opnd_b),
    .clk           (clk),
    .rst_n         (rst_n),
    .opcode        (opcode),
    .cin           (cin),
    .y             (y),
    .out_valid     (out_valid),
    .carry_flag    (carry_flag),
    .zero_flag     (zero_flag),
    .sign_flag     (sign_flag),
    .overflow_flag (overflow_flag)
  );

  // ---------------- clock: 10 ns period ----------------
  initial clk = 0;
  always #5 clk = ~clk;

  // ---------------- tasks ----------------
  // Rule: every task starts and ends at a falling edge.

  // Apply one operation; returns after the ALU has captured it.
  task drive_op(input logic [3:0] op,
                input logic [width-1:0] a, b,
                input logic ci);
    opcode   = op;
    opnd_a   = a;
    opnd_b   = b;
    cin      = ci;
    in_valid = 1;
    @(negedge clk);
  endtask

  // Hold in_valid low for n cycles.
  task idle(input int n);
    in_valid = 0;
    repeat (n) @(negedge clk);
  endtask

  // Compare all outputs with expected values (order: y, C, Z, N, V).
  task check_result(input int id,
                    input logic [width-1:0] ex_y,
                    input logic ex_c, ex_z, ex_s, ex_ov);
    if (out_valid     === 1'b1 &&
        y             === ex_y &&
        carry_flag    === ex_c &&
        zero_flag     === ex_z &&
        sign_flag     === ex_s &&
        overflow_flag === ex_ov) begin
      pass_count++;
      $display("PASS #%0d: y=%h c=%b z=%b n=%b v=%b",
               id, y, carry_flag, zero_flag, sign_flag, overflow_flag);
    end
    else begin
      fail_count++;
      $display("FAIL #%0d at %0t: out_valid=%b", id, $time, out_valid);
      $display("   expected y=%h c=%b z=%b n=%b v=%b",
               ex_y, ex_c, ex_z, ex_s, ex_ov);
      $display("   actual   y=%h c=%b z=%b n=%b v=%b",
               y, carry_flag, zero_flag, sign_flag, overflow_flag);
    end
  endtask

  // ---------------- test ----------------
  initial begin
    // known values at time 0, reset asserted
    rst_n = 0; in_valid = 0; opcode = 0; opnd_a = 0; opnd_b = 0; cin = 0;
    repeat (2) @(negedge clk);
    rst_n = 1;                                   // release reset at a falling edge

    // Section 6 reference vectors, back to back.
    //        op      a      b      cin           id  y      C  Z  N  V
    drive_op(OP_ADD, 8'h7F, 8'h01, 1'b0); check_result( 1, 8'h80, 0, 0, 1, 1);
    drive_op(OP_ADD, 8'hFF, 8'h01, 1'b0); check_result( 2, 8'h00, 1, 1, 0, 0);
    drive_op(OP_ADC, 8'hFF, 8'h00, 1'b1); check_result( 3, 8'h00, 1, 1, 0, 0);
    drive_op(OP_SUB, 8'h00, 8'h01, 1'b0); check_result( 4, 8'hFF, 1, 0, 1, 0);
    drive_op(OP_SUB, 8'h80, 8'h01, 1'b0); check_result( 5, 8'h7F, 0, 0, 0, 1);
    drive_op(OP_SBB, 8'h00, 8'h00, 1'b1); check_result( 6, 8'hFF, 1, 0, 1, 0);
    drive_op(OP_INC, 8'h7F, 8'h00, 1'b0); check_result( 7, 8'h80, 0, 0, 1, 1);
    drive_op(OP_DEC, 8'h00, 8'h00, 1'b0); check_result( 8, 8'hFF, 1, 0, 1, 0);
    drive_op(OP_DEC, 8'h80, 8'h00, 1'b0); check_result( 9, 8'h7F, 0, 0, 0, 1);
    drive_op(OP_XOR, 8'hA5, 8'hA5, 1'b0); check_result(10, 8'h00, 0, 1, 0, 0);
    drive_op(OP_SHL, 8'h81, 8'h01, 1'b0); check_result(11, 8'h02, 1, 0, 0, 0);
    drive_op(OP_SHL, 8'h01, 8'h07, 1'b0); check_result(12, 8'h80, 0, 0, 1, 0);
    drive_op(OP_SHL, 8'h81, 8'h00, 1'b0); check_result(13, 8'h81, 0, 0, 1, 0);
    drive_op(OP_SHR, 8'h81, 8'hF9, 1'b0); check_result(14, 8'h40, 1, 0, 0, 0);
    drive_op(OP_SAR, 8'h81, 8'h01, 1'b0); check_result(15, 8'hC0, 1, 0, 1, 0);
    drive_op(OP_SAR, 8'h80, 8'h07, 1'b0); check_result(16, 8'hFF, 0, 0, 1, 0);
    drive_op(OP_ROL, 8'h81, 8'h01, 1'b0); check_result(17, 8'h03, 1, 0, 0, 0);
    drive_op(OP_ROR, 8'h01, 8'h01, 1'b0); check_result(18, 8'h80, 1, 0, 1, 0);
    drive_op(OP_CMP, 8'h05, 8'h05, 1'b0); check_result(19, 8'h80, 0, 1, 0, 0);  // y held from #18
    drive_op(OP_CMP, 8'h03, 8'h05, 1'b0); check_result(20, 8'h80, 1, 0, 1, 0);  // y still held
    drive_op(OP_SBB, 8'h01, 8'h00, 1'b1); check_result(21, 8'h00, 0, 1, 0, 0);

    idle(2);

    // ---------------- summary ----------------
    $display("--------------------------------");
    $display("TOTAL: pass=%0d fail=%0d", pass_count, fail_count);
    if (fail_count == 0) $display("ALL DIRECTED TESTS PASSED");
    else                 $display("DIRECTED TESTS FAILED");
    $finish;
  end

endmodule
