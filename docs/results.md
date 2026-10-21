# Results

## Simulation

Self-checking directed testbench `tb/tb_alu.sv`, 21 golden vectors from [spec.md §5](spec.md#5-reference-vectors), run back to back after reset.

```
TOTAL: pass=21 fail=0
ALL DIRECTED TESTS PASSED
```

Each vector checks `out_valid`, `y`, `carry_flag`, `zero_flag`, `sign_flag` and `overflow_flag` using 4-state equality (`===`), so an `X` or `Z` on any output counts as a failure.

## Synthesis and implementation (Vivado 2025.1)

- **Part:** xc7a50tcpg236-1 (Artix-7)
- **Top:** `alu_top`, a wrapper that registers every input so all timing paths run flip-flop to flip-flop
- **Clock:** 10 ns (100 MHz), `constraints/alu_constraints.xdc`

### Utilisation

| Resource | `u_alu` (ALU core) | `alu_top` (total) |
| --- | --- | --- |
| Slice LUTs | 173 | 173 |
| Flip-flops | 13 | 35 |
| F7 muxes | 11 | 11 |
| Slices | – | 61 |
| Bonded IOB | – | 37 |
| BUFGCTRL | – | 1 |

The ALU core uses 13 flip-flops: 8 for `y`, 4 for the flags and 1 for `out_valid`. The other 22 belong to the wrapper's input registers (8 + 8 + 4 + 1 + `in_valid`).

### Timing (post-implementation)

| Metric | Value |
| --- | --- |
| WNS (setup) | +3.798 ns |
| TNS | 0.000 ns |
| WHS (hold) | +0.315 ns |
| WPWS | +4.500 ns |
| Failing endpoints | 0 |

All user-specified timing constraints are met.

**Estimated Fmax ≈ 1 / (10 ns − 3.798 ns) ≈ 161 MHz.**

### Worst setup paths

| # | From | To | Slack (ns) | Logic levels | Data path (ns) |
| --- | --- | --- | --- | --- | --- |
| 1 | `opnd_b_r[1]` | `u_alu/sign_flag_reg` | 3.798 | 7 | 6.170 (logic 2.289, route 3.881) |
| 2 | `opnd_b_r` | `u_alu/y_reg[7]` | 3.803 | – | 6.167 |
| 3 | `opnd_a_r[3]` | `u_alu/zero_flag_reg` | 3.971 | 6 | 5.999 |
| 4 | – | `u_alu/overflow_flag_reg` | 4.033 | – | – |
| 5 | – | `u_alu/carry_flag_reg` | 4.309 | – | – |

### Reading the critical path

- **It starts at the shift amount.** `opnd_b[1]` is part of `shift_amt = opnd_b[2:0]`, which drives every mux stage of the barrel shifter (fanout 44). The path then runs through the result mux into `flag_src` and the sign flag.
- **The adder isn't the slowest path.** On a 7-series FPGA, `+` and `−` map onto the dedicated CARRY4 chain, which is very fast. The shifter is built from general LUTs and F7 muxes, so it ends up longer.
- **Routing is about 63% of the delay** (3.881 of 6.170 ns). That's typical for a small, wide mux structure, where high-fanout control signals have to reach many LUTs.
- **The flags are behind `y`.** Z needs a reduction over all 8 bits of the result, and N and Z both go through the extra `flag_src` mux used by CMP.
