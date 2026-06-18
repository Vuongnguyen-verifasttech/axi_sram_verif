`timescale 1ns/1ps

class axi4_reset_sanity_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_reset_sanity_seq)

    function new(string name = "axi4_reset_sanity_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_reset_seq reset_seq;

        super.body();

        //-----------------------------------------
        // Apply reset
        //-----------------------------------------

        reset_seq =
        axi4_reset_seq::type_id::create("reset_seq");

        reset_seq.start(vseqr);

        //-----------------------------------------
        // Ready signals
        //-----------------------------------------

        if (vseqr.vif.awready !== 1'b1)
            `uvm_error(get_type_name(),
                       "AWREADY is not HIGH after reset")

        if (vseqr.vif.arready !== 1'b1)
            `uvm_error(get_type_name(),
                       "ARREADY is not HIGH after reset")

        //-----------------------------------------
        // Valid signals
        //-----------------------------------------

        if (vseqr.vif.bvalid !== 1'b0)
            `uvm_error(get_type_name(),
                       "BVALID is not LOW after reset")

        if (vseqr.vif.rvalid !== 1'b0)
            `uvm_error(get_type_name(),
                       "RVALID is not LOW after reset")

        `uvm_info(get_type_name(),
                  "Reset sanity checks passed",
                  UVM_LOW)
        //-----------------------------------------
        // FIFO signals
        //-----------------------------------------
        assert(vif.awfifo_empty)
            else `uvm_error("RESET", "AW FIFO not empty");

        assert(vif.arfifo_empty)
            else `uvm_error("RESET", "AR FIFO not empty");

        assert(vif.wfifo_empty)
            else `uvm_error("RESET", "W FIFO not empty");

        assert(vif.rfifo_empty)
            else `uvm_error("RESET", "R FIFO not empty");

        assert(vif.bfifo_empty)
            else `uvm_error("RESET", "B FIFO not empty");

        

    endtask

endclass