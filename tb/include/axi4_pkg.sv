//==============================================================================
// File          : axi4_pkg.sv
// Description   : UVM Package - Chỉ import UVM (không include class)
//==============================================================================

`ifndef AXI4_PKG_SV
`define AXI4_PKG_SV

package axi4_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

endpackage : axi4_pkg

`endif // AXI4_PKG_SV