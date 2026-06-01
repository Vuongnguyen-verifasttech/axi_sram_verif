//==============================================================================
// File          : axi4_env.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Environment
//                 - Creates AXI4 Agent
//                 - Passes virtual interface to Agent via config_db
//
// Version       : 1.1 (Fixed vif passing)
// Date          : 29-May-2026
//==============================================================================

class axi4_env extends uvm_env;

  `uvm_component_utils(axi4_env)

  axi4_agent agent;

  function new(string name = "axi4_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Tạo Agent
    agent = axi4_agent::type_id::create("agent", this);

    // Truyền virtual interface xuống Agent (và xuống driver/monitor)
    if (!uvm_config_db#(virtual axi4_if.driver)::set(this, "agent*", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Failed to set virtual interface to agent!")
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Sau này sẽ connect analysis_port của agent sang scoreboard
  endfunction

endclass : axi4_env