`timescale 1ns/1ps

// =============================================================================
// axi4_sequencer.sv
// Sequencer cho AXI4 Master Agent - Phân phối transaction từ sequence đến driver
// =============================================================================

class axi4_sequencer extends uvm_sequencer #(axi4_transaction);

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_component_utils(axi4_sequencer)

    // Constructor
    function new(string name = "axi4_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =====================================================================
    // (Hiện tại không cần thêm phase nào khác)
    // Sau này có thể thêm virtual sequencer hoặc arbitration ở đây
    // =====================================================================

endclass : axi4_sequencer