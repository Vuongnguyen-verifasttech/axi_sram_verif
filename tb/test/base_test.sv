//==============================================================================
// File          : base_test.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Base Test
//                 - Base class for all AXI4 tests
//                 - Creates axi4_env
//                 - Provides common run_phase flow (objection + sequence starter)
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  // Environment
  axi4_env env;

  // =====================================================================
  // Constructor
  // =====================================================================
  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // =====================================================================
  // Build Phase: Tạo Environment
  // =====================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi4_env::type_id::create("env", this);
    `uvm_info(get_type_name(), "Base test environment created", UVM_LOW)
  endfunction

  // =====================================================================
  // Run Phase: Main test flow
  // =====================================================================
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);

    phase.raise_objection(this, "Starting base test sequence");

    `uvm_info(get_type_name(), "=== BASE TEST START ===", UVM_LOW)

    // TODO: Sau này sẽ gọi sequence mặc định hoặc virtual sequence
    // Ví dụ: 
    // axi4_base_seq seq = axi4_base_seq::type_id::create("seq");
    // seq.start(env.agent.sequencer);

    #1000;   // temporary delay để testbench chạy

    `uvm_info(get_type_name(), "=== BASE TEST FINISHED ===", UVM_LOW)

    phase.drop_objection(this, "Base test finished");
  endtask

  // =====================================================================
  // End of Test Report
  // =====================================================================
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "Base test completed successfully", UVM_LOW)
  endfunction

endclass : base_test