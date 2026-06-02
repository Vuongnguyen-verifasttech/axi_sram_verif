//==============================================================================
// File          : axi4_write_seq.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Sequence for AXI4 Write Burst
//                 - Generates randomized or directed write transactions
//                 - Can be extended for specific test scenarios
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

class axi4_write_seq extends axi4_base_seq;

  `uvm_object_utils(axi4_write_seq)

  // =====================================================================
  // Constructor
  // =====================================================================
  function new(string name = "axi4_write_seq");
    super.new(name);
  endfunction

  // =====================================================================
  // Body task - Main stimulus
  // =====================================================================
  virtual task body();
    axi4_transaction tr;

    `uvm_info(get_type_name(), "=== Starting AXI4 Write Sequence ===", UVM_LOW)

    // Tạo 1 transaction write
    tr = axi4_transaction::type_id::create("tr_write");

    start_item(tr);

    // Randomize với constraint write
    if (!tr.randomize() with {
      is_write == 1;                    // Bắt buộc là Write
      axlen inside {[0:15]};            // Giới hạn burst length ban đầu
    }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize write transaction!")
    end

    finish_item(tr);

    `uvm_info(get_type_name(), $sformatf("Sent Write Transaction: %s", tr.convert2string()), UVM_MEDIUM)
  endtask

endclass : axi4_write_seq