//==============================================================================
// File          : axi4_pkg.sv
// Description   : UVM Package - Includes all verification components in order
//==============================================================================

`ifndef AXI4_PKG_SV
`define AXI4_PKG_SV

package axi4_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // 1. Thành phần dữ liệu (Data item)
  `include "axi4_transaction.sv"

  // 2. Kịch bản tạo kích thích (Sequences)
  `include "axi4_base_seq.sv"
  `include "axi4_write_seq.sv"

  // 3. Các thành phần cốt lõi trong Agent
  `include "axi4_sequencer.sv"
  `include "axi4_driver.sv"
  `include "axi4_monitor.sv"
  `include "axi4_agent.sv"

  // 4. Khối kiểm tra dữ liệu đầu ra
  `include "axi4_scoreboard.sv"

  // 5. Khối bọc môi trường (Environment)
  `include "axi4_env.sv"

endpackage : axi4_pkg

`endif // AXI4_PKG_SV