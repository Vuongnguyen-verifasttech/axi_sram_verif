//==============================================================================
// File          : axi4_pkg.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : Main UVM Package - Chỉ include các class
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

`ifndef AXI4_PKG_SV
`define AXI4_PKG_SV

package axi4_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Chỉ include các class (không include interface hay module)
  `include "../sequence/axi4_transaction.sv"
  `include "../sequence/axi4_base_seq.sv"
  `include "../sequence/axi4_write_seq.sv"

  `include "../agent/axi4_sequencer.sv"
  `include "../agent/axi4_driver.sv"
  `include "../agent/axi4_monitor.sv"
  `include "../agent/axi4_agent.sv"

  `include "../env/axi4_env.sv"
  `include "../scoreboard/axi4_scoreboard.sv"
  `include "../test/base_test.sv"

endpackage : axi4_pkg

`endif // AXI4_PKG_SV