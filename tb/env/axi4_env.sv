//==============================================================================
// File          : axi4_env.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Environment - Chỉ tạo Agent và để tb_top truyền vif
//
// Version       : 1.2 (Fixed vif error)
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

    // KHÔNG set vif ở đây nữa (tb_top đã set rồi)
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Sau này nối scoreboard ở đây
  endfunction

endclass : axi4_env