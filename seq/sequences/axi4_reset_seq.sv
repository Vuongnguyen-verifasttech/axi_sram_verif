`timescale 1ns/1ps

class axi4_reset_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_reset_seq)

    //--------------------------------------------------------------------------
    // Random reset width
    //--------------------------------------------------------------------------

    rand int unsigned reset_cycles;

    constraint c_reset_cycles {
        reset_cycles inside {[5:20]};
    }

    //--------------------------------------------------------------------------
    // Constructor
    //--------------------------------------------------------------------------

    function new(string name = "axi4_reset_seq");
        super.new(name);
    endfunction

    //--------------------------------------------------------------------------
    // Body
    //--------------------------------------------------------------------------

    virtual task body();

        super.body();

        if (!randomize()) begin
            `uvm_warning(get_type_name(),
                         "Randomization failed, use reset_cycles = 10")
            reset_cycles = 10;
        end

        `uvm_info(get_type_name(),
                  $sformatf("Applying reset for %0d cycles",
                            reset_cycles),
                  UVM_MEDIUM)

        //------------------------------------------------------
        // Assert reset
        //------------------------------------------------------

        vseqr.vif.i_rst_n <= 1'b0;

        repeat (reset_cycles)
            @(posedge vseqr.vif.i_clk);

        //------------------------------------------------------
        // Release reset
        //------------------------------------------------------

        vseqr.vif.i_rst_n <= 1'b1;

        //------------------------------------------------------
        // Wait DUT settle
        //------------------------------------------------------

        repeat (5)
            @(posedge vseqr.vif.i_clk);

        `uvm_info(get_type_name(),
                  "Reset sequence completed",
                  UVM_MEDIUM)

    endtask

endclass : axi4_reset_seq