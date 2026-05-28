# =============================================
# Corrected run.f cho pulp-platform/axi + QuestaSim
# =============================================

+incdir+../axi_lib/include
+incdir+../axi_lib/axi

# Package phải compile ĐẦU TIÊN
../axi_lib/src/axi_pkg.sv
../axi_lib/src/axi_intf.sv

# Sau đó mới đến typedef và assign
../axi_lib/include/axi/typedef.svh
../axi_lib/include/axi/assign.svh

# DUT
../axi_lib/src/axi_sim_mem.sv

# Testbench
../tb/axi_if.sv
../tb/tb_top.sv