//==============================================================================
// File          : axi4_agent.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Agent for AXI4 Master
//                 - Contains Sequencer + Driver + Monitor
//                 - Supports active mode (drive) and passive mode (monitor only)
//                 - Connects all sub-components correctly
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

class axi4_agent extends uvm_agent;

  `uvm_component_utils(axi4_agent)

  // Sub-components
  axi4_sequencer  sequencer;
  axi4_driver     driver;
  axi4_monitor    monitor;

  // Analysis port expose ra ngoài (cho Scoreboard/Coverage)
  uvm_analysis_port #(axi4_transaction) analysis_port;

  // =====================================================================
  // Constructor
  // =====================================================================
  function new(string name = "axi4_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // =====================================================================
  // Build Phase: Tạo các sub-component
  // =====================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Tạo monitor (luôn tạo, dù active hay passive)
    monitor = axi4_monitor::type_id::create("monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = axi4_sequencer::type_id::create("sequencer", this);
      driver    = axi4_driver::type_id::create("driver", this);
    end

    analysis_port = new("analysis_port", this);
  endfunction

  // =====================================================================
  // Connect Phase: Nối các port
  // =====================================================================
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (get_is_active() == UVM_ACTIVE) begin
      // Kết nối Driver với Sequencer
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end

    // Kết nối analysis port của Monitor ra ngoài Agent
    monitor.ap.connect(analysis_port);
  endfunction

endclass : axi4_agent