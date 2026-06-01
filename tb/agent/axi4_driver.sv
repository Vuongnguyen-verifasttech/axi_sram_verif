//==============================================================================
// File          : axi4_driver.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : AXI4 Master Driver
//                 - Drive all 5 AXI channels (AW, W, B, AR, R)
//                 - Use clocking block cb_driver to avoid race condition
//                 - Provide task-based API: write_burst(), read_burst()
//                 - Support random wait states and back-pressure handling
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

class axi4_driver extends uvm_driver #(axi4_transaction);

  `uvm_component_utils(axi4_driver)

  // Virtual interface để drive signals
  virtual axi4_if.driver vif;

  // =====================================================================
  // Constructor
  // =====================================================================
  function new(string name = "axi4_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // =====================================================================
  // Build Phase: Lấy virtual interface từ config_db
  // =====================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_if.driver)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface (vif) not found in config_db!")
    end
  endfunction

  // =====================================================================
  // Run Phase: Main driver loop
  // =====================================================================
  virtual task run_phase(uvm_phase phase);
    reset_driver();
    forever begin
      axi4_transaction req;                    
      seq_item_port.get_next_item(req);

      `uvm_info(get_type_name(), $sformatf("Driving: %s", req.convert2string()), UVM_MEDIUM)

      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  // =====================================================================
  // Reset task
  // =====================================================================
  virtual task reset_driver();
    vif.cb_driver.awvalid <= 1'b0;
    vif.cb_driver.wvalid  <= 1'b0;
    vif.cb_driver.arvalid <= 1'b0;
    vif.cb_driver.bready  <= 1'b1;   // Master luôn ready nhận response
    vif.cb_driver.rready  <= 1'b1;   // Master luôn ready nhận data
  endtask

  // =====================================================================
  // Drive task
  // =====================================================================
  virtual task drive_item(axi4_transaction tr);
    if (tr.is_write)
      drive_write_burst(tr);
    else
      drive_read_burst(tr);
  endtask

  // =====================================================================
  // Drive Write Burst
  // =====================================================================
  virtual task drive_write_burst(axi4_transaction tr);
    int num_beats = tr.axlen + 1;

    // 1. Drive AW Channel
    vif.cb_driver.awvalid <= 1'b1;
    vif.cb_driver.awaddr  <= tr.axaddr;
    vif.cb_driver.awlen   <= tr.axlen;
    vif.cb_driver.awburst <= tr.axburst;
    vif.cb_driver.awid    <= tr.axid;

    wait(vif.cb_driver.awready);
    @(vif.cb_driver);
    vif.cb_driver.awvalid <= 1'b0;

    // 2. Drive W Channel (từng beat)
    foreach (tr.data[i]) begin
      vif.cb_driver.wvalid <= 1'b1;
      vif.cb_driver.wdata  <= tr.data[i];
      vif.cb_driver.wlast  <= (i == num_beats - 1);

      wait(vif.cb_driver.wready);
      @(vif.cb_driver);
      vif.cb_driver.wvalid <= 1'b0;
    end
  endtask

  // =====================================================================
  // Drive Read Burst
  // =====================================================================
  virtual task drive_read_burst(axi4_transaction tr);
    vif.cb_driver.arvalid <= 1'b1;
    vif.cb_driver.araddr  <= tr.axaddr;
    vif.cb_driver.arlen   <= tr.axlen;
    vif.cb_driver.arburst <= tr.axburst;
    vif.cb_driver.arid    <= tr.axid;

    wait(vif.cb_driver.arready);
    @(vif.cb_driver);
    vif.cb_driver.arvalid <= 1'b0;
  endtask

endclass : axi4_driver




