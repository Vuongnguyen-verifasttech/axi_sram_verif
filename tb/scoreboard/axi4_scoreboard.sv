//==============================================================================
// File          : axi4_scoreboard.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Scoreboard for AXI4 SRAM
//                 - Receives transactions from Monitor
//                 - Compares DUT behavior with Reference Memory Model
//                 - Checks Write and Read data correctness
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

class axi4_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(axi4_scoreboard)

  // Analysis export nhận transaction từ Agent/Monitor
  uvm_analysis_imp #(axi4_transaction, axi4_scoreboard) analysis_export;

  // Reference Model: mô phỏng SRAM (sparse memory)
  protected bit [31:0] ref_mem [bit [31:0]];

  // Constructor
  function new(string name = "axi4_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  // =====================================================================
  // Write method - được gọi tự động khi Monitor gửi transaction
  // =====================================================================
  virtual function void write(axi4_transaction tr);
    if (tr.is_write) begin
      write_to_ref_model(tr);
    end else begin
      check_read_from_ref_model(tr);
    end
  endfunction

  // =====================================================================
  // Write transaction → cập nhật Reference Memory
  // =====================================================================
  virtual function void write_to_ref_model(axi4_transaction tr);
    bit [31:0] addr = tr.axaddr;
    foreach (tr.data[i]) begin
      ref_mem[addr] = tr.data[i];
      `uvm_info(get_type_name(), $sformatf("REF_WRITE: Addr=0x%8h, Data=0x%8h", addr, tr.data[i]), UVM_HIGH)
      addr += 4;   // increment theo 32-bit word
    end
  endfunction

  // =====================================================================
  // Read transaction → so sánh với Reference Memory
  // =====================================================================
  virtual function void check_read_from_ref_model(axi4_transaction tr);
    bit [31:0] addr = tr.axaddr;
    bit mismatch = 0;

    foreach (tr.data[i]) begin
      if (!ref_mem.exists(addr)) begin
        `uvm_error(get_type_name(), $sformatf("READ_UNINIT: Addr=0x%8h chưa được ghi dữ liệu!", addr))
        mismatch = 1;
      end else if (ref_mem[addr] != tr.data[i]) begin
        `uvm_error(get_type_name(), $sformatf("DATA_MISMATCH: Addr=0x%8h | Expected=0x%8h | Actual=0x%8h", 
                  addr, ref_mem[addr], tr.data[i]))
        mismatch = 1;
      end else begin
        `uvm_info(get_type_name(), $sformatf("READ_OK: Addr=0x%8h, Data=0x%8h", addr, tr.data[i]), UVM_HIGH)
      end
      addr += 4;
    end

    if (!mismatch)
      `uvm_info(get_type_name(), "READ transaction PASSED", UVM_MEDIUM);
  endfunction

endclass : axi4_scoreboard