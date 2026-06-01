//==============================================================================
// File          : axi4_pkg.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Package for AXI4 SRAM Verification
//                 - Import UVM package
//                 - Include all UVM components (transaction, driver, monitor, agent, env...)
//                 - Central place to manage all AXI4 verification classes
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

`ifndef AXI4_PKG_SV
`define AXI4_PKG_SV

package axi4_pkg;

  // Import UVM
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Include all UVM classes (sẽ include dần khi tạo)
  `include "sequence/axi4_transaction.sv"
  // `include "agent/axi4_driver.sv"
  // `include "agent/axi4_monitor.sv"
  // `include "agent/axi4_sequencer.sv"
  // `include "agent/axi4_agent.sv"
  // `include "env/axi4_env.sv"
  // `include "scoreboard/axi4_scoreboard.sv"
  // `include "test/base_test.sv"

endpackage : axi4_pkg

`endif // AXI4_PKG_SV