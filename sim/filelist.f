# =============================================================================
# Filelist AXI4 UVM - QuestaSim 10.6b (FINAL FIXED)
# =============================================================================

# RTL DUT
../rtl/m_vlsi_arbiter.sv
../rtl/m_vlsi_axfsm.sv
../rtl/m_vlsi_fifo.sv
../rtl/m_vlsi_sram_misc.sv
../rtl/m_vlsi_axi4_sram.sv

# Interface
../tb/interface/axi4_if.sv

# Package
../tb/include/axi4_pkg.sv

# TB Classes (compile trực tiếp)
../tb/sequence/axi4_transaction.sv
../tb/sequence/axi4_base_seq.sv
../tb/sequence/axi4_write_seq.sv

../tb/agent/axi4_sequencer.sv
../tb/agent/axi4_driver.sv
../tb/agent/axi4_monitor.sv
../tb/agent/axi4_agent.sv

../tb/env/axi4_env.sv
../tb/scoreboard/axi4_scoreboard.sv
../tb/test/base_test.sv

# Wrapper + Top
../tb/dut_wrapper.sv
../tb/top/tb_top.sv