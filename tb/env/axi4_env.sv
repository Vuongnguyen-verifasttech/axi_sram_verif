//==============================================================================
// File          : axi4_env.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Environment - Creates and connects Agent and Scoreboard
//
// Version       : 1.3 (Connected Scoreboard)
// Date          : 01-June-2026
//==============================================================================

class axi4_env extends uvm_env;

  `uvm_component_utils(axi4_env)

  // Khai báo các thành phần môi trường
  axi4_agent      agent;
  axi4_scoreboard scoreboard;

  // Constructor
  function new(string name = "axi4_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // =====================================================================
  // Build Phase: Tạo Agent và Scoreboard thông qua Factory
  // =====================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent      = axi4_agent::type_id::create("agent", this);
    scoreboard = axi4_scoreboard::type_id::create("scoreboard", this);
  endfunction

  // =====================================================================
  // Connect Phase: Thực hiện liên kết các cổng Analysis Port
  // =====================================================================
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Kết nối cổng thu thập dữ liệu từ Monitor (thông qua Agent) tới Scoreboard
    agent.analysis_port.connect(scoreboard.analysis_export);
  endfunction

endclass : axi4_env