//==============================================================================
// File          : axi4_env.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Environment for AXI4 SRAM Verification
//                 - Contains AXI4 Agent (Driver + Monitor + Sequencer)
//                 - Will contain Scoreboard and Coverage in the future
//                 - Central place to configure active/passive mode
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

class axi4_env extends uvm_env;

  `uvm_component_utils(axi4_env)

  // Sub-components
  axi4_agent   agent;

  // =====================================================================
  // Constructor
  // =====================================================================
  function new(string name = "axi4_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // =====================================================================
  // Build Phase: Tạo agent và truyền virtual interface
  // =====================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Tạo AXI4 Agent
    agent = axi4_agent::type_id::create("agent", this);

    // Truyền virtual interface xuống agent (và xuống driver/monitor bên trong)
    if (!uvm_config_db#(virtual axi4_if.driver)::set(this, "agent*", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Failed to set virtual interface to agent!")
    end
  endfunction

  // =====================================================================
  // Connect Phase (sẽ nối scoreboard sau)
  // =====================================================================
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Sau này sẽ connect: agent.analysis_port.connect(scoreboard.analysis_export);
  endfunction

endclass : axi4_env