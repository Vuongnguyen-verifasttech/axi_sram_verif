`timescale 1ns/1ps

// =============================================================================
// axi4_transaction.sv
// Class đại diện cho 1 transaction AXI4 (Write hoặc Read burst)
// =============================================================================

class axi4_transaction extends uvm_sequence_item;

    // =====================================================================
    // Parameters (phải khớp với DUT)
    // =====================================================================
    localparam PARA_ADDR_WD = 32;
    localparam PARA_DATA_WD = 32;
    localparam PARA_ID_WD   = 4;
    localparam PARA_LEN_WD  = 8;

    // =====================================================================
    // Transaction Fields
    // =====================================================================
    rand bit [PARA_ADDR_WD-1:0]     awaddr;      // Write address
    rand bit [PARA_ADDR_WD-1:0]     araddr;      // Read address
    rand bit [PARA_ID_WD-1:0]       id;          // Transaction ID
    rand bit [PARA_LEN_WD-1:0]      len;         // Burst length = len + 1
    rand bit [1:0]                  burst;       // 00=FIXED, 01=INCR, 10=WRAP
    rand bit [PARA_DATA_WD-1:0]     data[$];     // Queue data cho tất cả beat
    rand bit                        is_write;    // 1 = Write transaction, 0 = Read

    // Response fields (monitor sẽ capture)
    bit [1:0]                       resp;        // BRESP / RRESP
    bit                             last;        // WLAST / RLAST

    // =====================================================================
    // Constraints - Điều khiển random stimulus
    // =====================================================================
    constraint c_burst_type {
        burst inside {2'b00, 2'b01, 2'b10};           // Chỉ hỗ trợ FIXED, INCR, WRAP
    }

    constraint c_len_range {
        len inside {[0:255]};                         // AXI4 max 256 beats
    }

    constraint c_data_size {
        data.size() == (len + 1);                     // Số beat = len + 1
    }

    constraint c_addr_alignment {
        if (burst == 2'b10)                           // WRAP burst
            (awaddr[1:0] == 0) && (araddr[1:0] == 0); // Phải aligned 4-byte
    }

    constraint c_write_read_ratio {
        is_write dist {1 := 60, 0 := 40};            // 60% write, 40% read
    }

    // =====================================================================
    // UVM Automation Macro
    // =====================================================================
    `uvm_object_utils_begin(axi4_transaction)
        `uvm_field_int(awaddr,    UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(araddr,    UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(id,        UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(len,       UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(burst,     UVM_ALL_ON | UVM_BIN)
        `uvm_field_queue_int(data, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(is_write,  UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(resp,      UVM_ALL_ON | UVM_BIN)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "axi4_transaction");
        super.new(name);
    endfunction

    // =====================================================================
    // Utility functions (bắt buộc cho UVM)
    // =====================================================================
    virtual function void do_copy(uvm_object rhs);
        axi4_transaction rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("DO_COPY", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        awaddr   = rhs_.awaddr;
        araddr   = rhs_.araddr;
        id       = rhs_.id;
        len      = rhs_.len;
        burst    = rhs_.burst;
        data     = rhs_.data;
        is_write = rhs_.is_write;
        resp     = rhs_.resp;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer = null);
        axi4_transaction rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (awaddr   == rhs_.awaddr) &&
               (araddr   == rhs_.araddr) &&
               (id       == rhs_.id)     &&
               (len      == rhs_.len)    &&
               (burst    == rhs_.burst)  &&
               (data     == rhs_.data)   &&
               (is_write == rhs_.is_write) &&
               (resp     == rhs_.resp);
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("TYPE=%s | ID=0x%0h | ADDR=0x%0h | LEN=%0d | BURST=%0d | DATA_SIZE=%0d",
                      is_write ? "WRITE" : "READ", id, 
                      is_write ? awaddr : araddr, len, burst, data.size());
        return s;
    endfunction

endclass : axi4_transaction