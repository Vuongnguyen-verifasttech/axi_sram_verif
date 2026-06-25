`timescale 1ns/1ps

class axi4_wr_seq_item extends uvm_sequence_item;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam ADDR_WD = 32;
    localparam DATA_WD = 32;
    localparam ID_WD   = 4;
    localparam LEN_WD  = 8;

    // =========================================================================
    // AW Channel
    // =========================================================================
    rand logic [ADDR_WD-1:0] awaddr;
    rand logic [ID_WD-1:0]   awid;
    rand logic [LEN_WD-1:0]  awlen;
    rand logic [1:0]         awburst;   // FIXED=00, INCR=01, WRAP=10

    // =========================================================================
    // W Channel
    // =========================================================================
    rand logic [DATA_WD-1:0] wdata[$];

    // =========================================================================
    // B Channel (filled by driver/monitor)
    // =========================================================================
    logic [1:0]             bresp;
    logic [ID_WD-1:0]       bid;

    // =========================================================================
    // Constraints
    // =========================================================================

    // Supported burst types only
    constraint c_burst_type {
      //  awburst inside {2'b00, 2'b01, 2'b10};
      awburst inside {2'b01};
    }

    // Limit burst length for faster simulation
    constraint c_len_range {
        awlen inside {[0:15]};
    }

    // Number of data beats must match burst length
    constraint c_wdata_size {
        wdata.size() == (awlen + 1);
    }

    // DUT requires word-aligned address (32-bit data width)
    constraint c_addr_align {
        awaddr[1:0] == 2'b00;
    }

    // SRAM address range (4KB)
    constraint c_addr_range {
        awaddr inside {[32'h0000_0000 : 32'h0000_0FFF]};
    }

    // =========================================================================
    // UVM Automation
    // =========================================================================
    `uvm_object_utils_begin(axi4_wr_seq_item)
        `uvm_field_int       (awaddr , UVM_ALL_ON | UVM_HEX)
        `uvm_field_int       (awid   , UVM_ALL_ON | UVM_HEX)
        `uvm_field_int       (awlen  , UVM_ALL_ON | UVM_DEC)
        `uvm_field_int       (awburst, UVM_ALL_ON | UVM_BIN)
        `uvm_field_queue_int (wdata  , UVM_ALL_ON | UVM_HEX)
        `uvm_field_int       (bresp  , UVM_ALL_ON | UVM_BIN)
        `uvm_field_int       (bid    , UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    // =========================================================================
    // Constructor
    // =========================================================================
    function new(string name = "axi4_wr_seq_item");
        super.new(name);
    endfunction

    // =========================================================================
    // Copy
    // =========================================================================
    virtual function void do_copy(uvm_object rhs);
        axi4_wr_seq_item rhs_;

        if (!$cast(rhs_, rhs))
            `uvm_fatal("WR_ITEM_COPY", "Cast failed")

        super.do_copy(rhs);

        awaddr  = rhs_.awaddr;
        awid    = rhs_.awid;
        awlen   = rhs_.awlen;
        awburst = rhs_.awburst;
        wdata   = rhs_.wdata;
        bresp   = rhs_.bresp;
        bid     = rhs_.bid;
    endfunction

    // =========================================================================
    // Compare (stimulus fields only)
    // =========================================================================
    virtual function bit do_compare(uvm_object rhs,
                                    uvm_comparer comparer = null);

        axi4_wr_seq_item rhs_;

        if (!$cast(rhs_, rhs))
            return 0;

        return ((awaddr  == rhs_.awaddr ) &&
                (awid    == rhs_.awid   ) &&
                (awlen   == rhs_.awlen  ) &&
                (awburst == rhs_.awburst) &&
                (wdata   == rhs_.wdata  ));
    endfunction

    // =========================================================================
    // String conversion
    // =========================================================================
    virtual function string convert2string();

        return $sformatf(
            "WRITE | AWID=0x%0h | AWADDR=0x%0h | AWLEN=%0d | AWBURST=%0b | BEATS=%0d | BID=0x%0h | BRESP=%0b",
            awid,
            awaddr,
            awlen,
            awburst,
            wdata.size(),
            bid,
            bresp
        );

    endfunction

endclass : axi4_wr_seq_item