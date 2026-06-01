# =============================================================================
# Filelist cho AXI4 SRAM UVM (QuestaSim 10.6b) - Đã sửa
# =============================================================================

# RTL DUT
../rtl/m_vlsi_arbiter.sv
../rtl/m_vlsi_axfsm.sv
../rtl/m_vlsi_fifo.sv
../rtl/m_vlsi_sram_misc.sv
../rtl/m_vlsi_axi4_sram.sv

# Include directories
+incdir+../tb/include
+incdir+../tb/interface

# Package (chỉ class)
../tb/include/axi4_pkg.sv

# Interface (compile riêng, KHÔNG nằm trong package)
../tb/interface/axi4_if.sv

../tb/dut_wrapper.sv

# Top module
../tb/top/tb_top.sv