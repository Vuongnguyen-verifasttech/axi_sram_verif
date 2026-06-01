//==============================================================================
// File          : axi4_sequencer.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Sequencer for AXI4 transactions
//                 - Acts as a router between Sequences and Driver
//                 - Uses parameterized uvm_sequencer
//
// Version       : 1.0
// Date          : 1-June-2026
//==============================================================================

class axi4_sequencer extends uvm_sequencer #(axi4_transaction);

  `uvm_component_utils(axi4_sequencer)

  // =====================================================================
  // Constructor
  // =====================================================================
  function new(string name = "axi4_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Sequencer trong UVM thường không cần thêm code gì nhiều
  // (virtual sequencer sẽ được thêm sau nếu cần)

endclass : axi4_sequencer