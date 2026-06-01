# =============================================================================
# Filelist cho AXI4 SRAM UVM Verification Environment (QuestaSim)
# =============================================================================

# UVM Library
+incdir+$UVM_HOME/src
$UVM_HOME/src/uvm_pkg.sv

# Package (phải compile trước)
+incdir+../tb/pkg
../tb/pkg/axi4_pkg.sv

# RTL (DUT)
../rtl/m_vlsi_arbiter.sv
../rtl/m_vlsi_axfsm.sv
../rtl/m_vlsi_fifo.sv
../rtl/m_vlsi_sram_misc.sv
../rtl/m_vlsi_axi4_sram.sv

# TB files
../tb/interface/axi4_if.sv

../tb/agent/axi4_sequencer.sv
../tb/agent/axi4_driver.sv
../tb/agent/axi4_monitor.sv
../tb/agent/axi4_agent.sv

../tb/sequence/axi4_transaction.sv
../tb/sequence/axi4_base_seq.sv
../tb/sequence/axi4_write_seq.sv

../tb/env/axi4_env.sv
../tb/scoreboard/axi4_scoreboard.sv
../tb/test/base_test.sv

# Top module
../tb/top/tb_top.sv