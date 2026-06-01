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
+incdir+../tb/agent
+incdir+../tb/sequence
+incdir+../tb/env
+incdir+../tb/scoreboard
+incdir+../tb/test

# Package (phải compile trước tất cả)
../tb/include/axi4_pkg.sv

# Interface
../tb/interface/axi4_if.sv

# Agent & Sequence
../tb/agent/axi4_sequencer.sv
../tb/agent/axi4_driver.sv
../tb/agent/axi4_monitor.sv
../tb/agent/axi4_agent.sv

../tb/sequence/axi4_transaction.sv
../tb/sequence/axi4_base_seq.sv
../tb/sequence/axi4_write_seq.sv

# Env, Scoreboard, Test, Top
../tb/env/axi4_env.sv
../tb/scoreboard/axi4_scoreboard.sv
../tb/test/base_test.sv
../tb/top/tb_top.sv