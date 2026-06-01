//==============================================================================
// File          : axi4_monitor.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Monitor for AXI4 Slave DUT
//                 - Passively collects complete AXI4 transactions (Write & Read)
//                 - Sends transaction to Scoreboard via analysis port
//                 - Supports both Write and Read paths in parallel
//
// Version       : 1.0
// Date          : 1-June-2026
//==============================================================================

class axi4_monitor extends uvm_monitor;
    `uvm_component_utils(axi4_monitor)

// virtual interface 
virtual axi4_if.monitor vif;

// Analysis port to broadcast trans --> SB 
uvm_analysis_port#(axi4_transaction) ap;

// =====================================================================
// Constructor
// =====================================================================

function new (string name = "axi4_monitor", uvm_component parent = null)
    super.new(name, parent);
endfunction

// =====================================================================
// Build phase 
// =====================================================================
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);

    if(!uvm_config_db#(virtual axi4_if.monitor)::get(this,"","vif", vif)) begin 
        `uvm_fatal(get_type_name(),"Can not get config_db!!!!")
    end
endfunction

// =====================================================================
// Run phase 
// =====================================================================
virtual task run_phase(uvm_phase phase);
    fork
        collect_write_transaction();
        collect_read_transaction();
    join
endtask 

// =====================================================================
// Collect Write Transaction (AW + W)
// =====================================================================
virtual task collect_write_transactions();
    axi4_transaction tr;
    forever begin
      tr = axi4_transaction::type_id::create("tr_write");

      // Wait for AW handshake
      wait(vif.cb_monitor.awvalid && vif.cb_monitor.awready);
      tr.axaddr  = vif.cb_monitor.awaddr;
      tr.axlen   = vif.cb_monitor.awlen;
      tr.axburst = axi4_transaction::axi_burst_e'(vif.cb_monitor.awburst); // type cast: convert 2 bit value from bus --> enum 
      tr.axid    = vif.cb_monitor.awid;
      tr.is_write = 1'b1;

      // Collect all W beats
      for (int i = 0; i <= tr.axlen; i++) begin
        wait(vif.cb_monitor.wvalid && vif.cb_monitor.wready);
        tr.data.push_back(vif.cb_monitor.wdata); // add an element to the end of queue 
        if (vif.cb_monitor.wlast) break;
        @(vif.cb_monitor);
      end

      `uvm_info(get_type_name(), $sformatf("Collected WRITE: %s", tr.convert2string()), UVM_MEDIUM);
      ap.write(tr);
    end
  endtask
// =====================================================================
  // Collect Read Transaction (AR + R)
  // =====================================================================
  virtual task collect_read_transactions();
    axi4_transaction tr;
    forever begin
      tr = axi4_transaction::type_id::create("tr_read");

      // Wait for AR handshake
      wait(vif.cb_monitor.arvalid && vif.cb_monitor.arready);
      tr.axaddr  = vif.cb_monitor.araddr;
      tr.axlen   = vif.cb_monitor.arlen;
      tr.axburst = axi4_transaction::axi_burst_e'(vif.cb_monitor.arburst);
      tr.axid    = vif.cb_monitor.arid;
      tr.is_write = 1'b0;

      // Collect all R beats
      for (int i = 0; i <= tr.axlen; i++) begin
        wait(vif.cb_monitor.rvalid && vif.cb_monitor.rready);
        tr.data.push_back(vif.cb_monitor.rdata);
        if (vif.cb_monitor.rlast) break;
        @(vif.cb_monitor);
      end

      `uvm_info(get_type_name(), $sformatf("Collected READ : %s", tr.convert2string()), UVM_MEDIUM);
      ap.write(tr);
    end
  endtask

endclass : axi4_monitor