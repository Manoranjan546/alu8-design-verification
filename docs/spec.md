# 8-bit ALU — Design Specification

Registered 8-bit ALU with 16 operations, four status flags (C, Z, N, V), single-cycle latency and a valid handshake. Written before the RTL; the RTL and testbench in this repository implement and check it.

## 1. Interface

Module `alu`, parameter `width = 8` (all numbers below assume 8).

| Port | Dir | Width | Description |
| --- | --- | --- | --- |
| `clk` | in | 1 | Rising-edge clock |
| `rst_n` | in | 1 | Asynchronous assert, active-low reset (deassertion assumed synchronised outside the ALU) |
| `in_valid` | in | 1 | Inputs below hold a real operation this cycle |
| `opcode` | in | 4 | Operation select (Section 2) |
| `opnd_a` | in | 8 | Operand A |
| `opnd_b` | in | 8 | Operand B; for shifts and rotates only `opnd_b[2:0]` is the shift amount |
| `cin` | in | 1 | Carry-in for ADC, borrow-in for SBB; ignored by all other operations |
| `out_valid` | out | 1 | `y` and the flags carry a new result this cycle |
| `y` | out | 8 | Result |
| `carry_flag` | out | 1 | C: carry / borrow / last bit shifted out |
| `zero_flag` | out | 1 | Z: result is zero |
| `sign_flag` | out | 1 | N: MSB of the result |
| `overflow_flag` | out | 1 | V: signed overflow |

All outputs are driven directly from flip-flops.

## 2. Operations

Opcodes are defined once in `alu_pkg.sv` as `typedef enum logic [3:0] opcode_t`. All 16 codes are legal. `sh = opnd_b[2:0]`.

| `opcode` | Name | Result `y` |
| --- | --- | --- |
| 0000 | `OP_ADD` | a + b |
| 0001 | `OP_ADC` | a + b + cin |
| 0010 | `OP_SUB` | a − b |
| 0011 | `OP_SBB` | a − b − cin |
| 0100 | `OP_INC` | a + 1 |
| 0101 | `OP_DEC` | a − 1 |
| 0110 | `OP_AND` | a & b |
| 0111 | `OP_OR` | a \| b |
| 1000 | `OP_XOR` | a ^ b |
| 1001 | `OP_NOT` | ~a |
| 1010 | `OP_SHL` | a << sh, zero fill |
| 1011 | `OP_SHR` | a >> sh, zero fill |
| 1100 | `OP_SAR` | a >>> sh, sign fill |
| 1101 | `OP_ROL` | a rotated left by sh |
| 1110 | `OP_ROR` | a rotated right by sh |
| 1111 | `OP_CMP` | **y holds its previous value**; flags computed from a − b |

## 3. Flags

Flags are recomputed on every accepted operation. Let `r` = `y` for every operation except CMP, where `r = a − b`.

- **Z** = (r == 0)
- **N** = r[7]

| Operation | C | V |
| --- | --- | --- |
| ADD, ADC | Carry out of bit 7 | a[7] == b[7] and r[7] != a[7] |
| INC | Carry out (1 only when a = 0xFF) | + to − transition |
| SUB, SBB, CMP | Borrow: 1 when the unsigned result went below zero | a[7] != b[7] and r[7] != a[7] |
| DEC | Borrow (1 only when a = 0x00) | − to + transition |
| AND, OR, XOR, NOT | 0 | 0 |
| SHL, sh ≥ 1 | a[8 − sh], last bit shifted out | 0 |
| SHR, SAR, sh ≥ 1 | a[sh − 1], last bit shifted out | 0 |
| ROL, sh ≥ 1 | y[0] | 0 |
| ROR, sh ≥ 1 | y[7] | 0 |
| Any shift or rotate, sh = 0 | 0 (and y = a) | 0 |

Borrow convention: C = 1 means a borrow occurred. `cin` in SBB has the same polarity, so SUB → SBB chains across bytes by feeding C into `cin`.

## 4. Timing, reset and handshake

1. **Accept:** on a rising edge with `in_valid = 1`, the result and all four flags are registered and `out_valid` goes to 1.
2. **Idle:** on a rising edge with `in_valid = 0`, `out_valid` goes to 0 and `y` and the flags hold.
3. **Latency:** exactly one clock; one operation per cycle, back-to-back operations supported.
4. **No backpressure:** there is no `ready`; the ALU always accepts.
5. **Reset:** while `rst_n = 0`, `y = 0`, all flags = 0, `out_valid = 0`, independent of the clock.
6. Inputs while `in_valid = 0` are don't-care and must not affect any output.

## 5. Reference vectors

Directed tests used by the testbench (hex; `–` = don't care). Rows run back to back after reset, so rows 19–20 expect `y` held from row 18.

| # | Op | a | b | cin | y | C | Z | N | V |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | ADD | 7F | 01 | – | 80 | 0 | 0 | 1 | 1 |
| 2 | ADD | FF | 01 | – | 00 | 1 | 1 | 0 | 0 |
| 3 | ADC | FF | 00 | 1 | 00 | 1 | 1 | 0 | 0 |
| 4 | SUB | 00 | 01 | – | FF | 1 | 0 | 1 | 0 |
| 5 | SUB | 80 | 01 | – | 7F | 0 | 0 | 0 | 1 |
| 6 | SBB | 00 | 00 | 1 | FF | 1 | 0 | 1 | 0 |
| 7 | INC | 7F | – | – | 80 | 0 | 0 | 1 | 1 |
| 8 | DEC | 00 | – | – | FF | 1 | 0 | 1 | 0 |
| 9 | DEC | 80 | – | – | 7F | 0 | 0 | 0 | 1 |
| 10 | XOR | A5 | A5 | – | 00 | 0 | 1 | 0 | 0 |
| 11 | SHL | 81 | 01 | – | 02 | 1 | 0 | 0 | 0 |
| 12 | SHL | 01 | 07 | – | 80 | 0 | 0 | 1 | 0 |
| 13 | SHL | 81 | 00 | – | 81 | 0 | 0 | 1 | 0 |
| 14 | SHR | 81 | F9 | – | 40 | 1 | 0 | 0 | 0 |
| 15 | SAR | 81 | 01 | – | C0 | 1 | 0 | 1 | 0 |
| 16 | SAR | 80 | 07 | – | FF | 0 | 0 | 1 | 0 |
| 17 | ROL | 81 | 01 | – | 03 | 1 | 0 | 0 | 0 |
| 18 | ROR | 01 | 01 | – | 80 | 1 | 0 | 1 | 0 |
| 19 | CMP | 05 | 05 | – | 80 (held) | 0 | 1 | 0 | 0 |
| 20 | CMP | 03 | 05 | – | 80 (held) | 1 | 0 | 1 | 0 |
| 21 | SBB | 01 | 00 | 1 | 00 | 0 | 1 | 0 | 0 |

Row 14 checks that `opnd_b[7:3]` is ignored (F9 → sh = 1). Rows 13 and 16 cover sh = 0 and sh = 7. Row 21 is a regression vector for the SBB overflow bug described in the README.
