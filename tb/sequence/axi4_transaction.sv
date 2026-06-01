//==============================================================================
// File          : axi4_transaction.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Sequence Item cho AXI4 transaction (professional version)
//                 - Abstract hóa một burst AXI4 (Write hoặc Read)
//                 - Dễ randomize, dễ debug, dễ mở rộng
//
// Version       : 1.2
// Date          : 29-May-2026
//==============================================================================

class axi4_transaction extends uvm_sequence_item;

  // =====================================================================
  // 1. Enum & Typedef
  // =====================================================================
  typedef enum bit [1:0] {
    AXI_BURST_FIXED = 2'b00,
    AXI_BURST_INCR  = 2'b01,
    AXI_BURST_WRAP  = 2'b10
  } axi_burst_e;

  // =====================================================================
  // 2. Transaction fields
  // =====================================================================
  rand bit [31:0]      axaddr;
  rand bit [7:0]       axlen;        // 0-255 beats
  rand axi_burst_e     axburst;
  rand bit             is_write;     // 1 = WRITE, 0 = READ

  rand bit [31:0]      data[$];      // chỉ dùng khi is_write == 1
  rand bit [3:0]       axid;

  // =====================================================================
  // 3. Constraints
  // =====================================================================
  constraint c_valid_burst {
    axburst inside {AXI_BURST_FIXED, AXI_BURST_INCR, AXI_BURST_WRAP};
  }

  constraint c_addr_alignment {
    axaddr[1:0] == 2'b00;          // DUT hiện chỉ hỗ trợ full-word 32-bit
  }

  constraint c_data_size {
    if (is_write) {
      data.size() == (axlen + 1);
    } else {
      data.size() == 0;
    }
  }

  constraint c_len_range {
    axlen inside {[0:63]};         // có thể mở rộng thành 255 sau
  }

  // =====================================================================
  // 4. UVM Automation
  // =====================================================================
  `uvm_object_utils_begin(axi4_transaction)
    `uvm_field_int     (axaddr,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_int     (axlen,    UVM_ALL_ON | UVM_DEC)
    `uvm_field_enum    (axi_burst_e, axburst, UVM_ALL_ON)
    `uvm_field_int     (is_write, UVM_ALL_ON)
    `uvm_field_int     (axid,     UVM_ALL_ON | UVM_DEC)
    `uvm_field_queue_int(data,    UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end

  // =====================================================================
  // 5. Constructor + Debug helper
  // =====================================================================
  function new(string name = "axi4_transaction");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string s;
    s = $sformatf("AXI4 %s | ID=0x%0h | ADDR=0x%8h | LEN=%0d | BURST=%s | DATA=%0d beats",
                  is_write ? "WRITE" : "READ ",
                  axid, axaddr, axlen, axburst.name(), data.size());
    return s;
  endfunction

endclass : axi4_transaction