# =============================================================================
# Filelist cho AXI4 SRAM UVM (QuestaSim 10.6b)
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

# Package (chỉ compile package này, các file khác được include bên trong)
../tb/include/axi4_pkg.sv

# Interface và Top
../tb/interface/axi4_if.sv
../tb/top/tb_top.sv