`timescale 1ns/1ps

// =============================================================================
// axi4_rd_seq_item.sv
// Sequence item cho AXI4 Read transaction (AR + R channels)
// Tách biệt hoàn toàn với Write — không còn field ambiguous
// =============================================================================

class axi4_rd_seq_item extends uvm_sequence_item;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam ADDR_WD = 32;
    localparam DATA_WD = 32;
    localparam ID_WD   = 4;
    localparam LEN_WD  = 8;

    // =========================================================================
    // AR channel fields — driven by driver
    // =========================================================================
    rand logic [ADDR_WD-1:0] araddr;
    rand logic [ID_WD-1:0]   arid;
    rand logic [LEN_WD-1:0]  arlen;
    rand logic [1:0]          arburst;

    // =========================================================================
    // R channel fields — filled by monitor
    // =========================================================================
    logic [DATA_WD-1:0] rdata[$];   // captured per beat
    logic [1:0]         rresp;      // response of last beat (OKAY / SLVERR)
    logic [ID_WD-1:0]   rid;        // ID của beat cuối

    // =========================================================================
    // Constraints
    // =========================================================================
    constraint c_burst_type {
        arburst inside {2'b00, 2'b01, 2'b10};
    }

    constraint c_len_range {
        arlen inside {[0:15]};
    }

    constraint c_addr_align {
        araddr[1:0] == 2'b00;
    }

    constraint c_addr_range {
        araddr inside {[32'h0000_0000 : 32'h0000_0FFF]};
    }

    // =========================================================================
    // UVM automation
    // =========================================================================
    `uvm_object_utils_begin(axi4_rd_seq_item)
        `uvm_field_int       (araddr,  UVM_ALL_ON | UVM_HEX)
        `uvm_field_int       (arid,    UVM_ALL_ON | UVM_HEX)
        `uvm_field_int       (arlen,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_int       (arburst, UVM_ALL_ON | UVM_BIN)
        `uvm_field_queue_int (rdata,   UVM_ALL_ON | UVM_HEX)
        `uvm_field_int       (rresp,   UVM_ALL_ON | UVM_BIN)
        `uvm_field_int       (rid,     UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "axi4_rd_seq_item");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        axi4_rd_seq_item rhs_;
        if (!$cast(rhs_, rhs))
            `uvm_fatal("RD_ITEM_COPY", "Cast failed")
        super.do_copy(rhs);
        araddr  = rhs_.araddr;
        arid    = rhs_.arid;
        arlen   = rhs_.arlen;
        arburst = rhs_.arburst;
        rdata   = rhs_.rdata;
        rresp   = rhs_.rresp;
        rid     = rhs_.rid;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer = null);
        axi4_rd_seq_item rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (araddr  == rhs_.araddr)  &&
               (arid    == rhs_.arid)    &&
               (arlen   == rhs_.arlen)   &&
               (arburst == rhs_.arburst);
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("READ  | ARID=0x%0h | ARADDR=0x%0h | ARLEN=%0d | ARBURST=%0b | BEATS=%0d | RRESP=%0b",
                      arid, araddr, arlen, arburst, rdata.size(), rresp);
        return s;
    endfunction

endclass : axi4_rd_seq_item