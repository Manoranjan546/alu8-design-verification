# alu_constraints.xdc : timing constraints for alu_top
# 100 MHz clock on port clk
create_clock -period 10.000 -name clk [get_ports clk]
