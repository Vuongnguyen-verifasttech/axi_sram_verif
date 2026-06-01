//==============================================================================
// File          : axi4_base_seq.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Base Sequence for AXI4
//                 - Base class for all AXI4 sequences
//                 - Provides common methods and default behavior
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

class axi4_base_seq extends uvm_sequence #(axi4_transaction);

  `uvm_object_utils(axi4_base_seq)

  function new(string name = "axi4_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Starting base sequence (empty by default)", UVM_LOW)
  endtask

  virtual task send_random_transaction();
    axi4_transaction tr = axi4_transaction::type_id::create("tr");
    start_item(tr);
    if (!tr.randomize()) `uvm_error(get_type_name(), "Randomize failed!")
    finish_item(tr);
    `uvm_info(get_type_name(), $sformatf("Sent: %s", tr.convert2string()), UVM_MEDIUM)
  endtask

endclass : axi4_base_seq