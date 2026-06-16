`timescale 1ns/1ps

class axi4_reset_seq extends uvm_sequence;

    `uvm_object_utils(axi4_reset_seq)

    axi4_virtual_seqr vseqr;

    rand int unsigned reset_cycles;

    constraint c_reset_cycles {
        reset_cycles inside {[5:20]};
    }

    function new(string name = "axi4_reset_seq");
        super.new(name);
    endfunction

    virtual task body();

        if (!$cast(vseqr, m_sequencer)) begin
            `uvm_fatal(get_type_name(),
                       "Cannot cast m_sequencer to axi4_virtual_seqr")
        end

        if (!randomize()) begin
            reset_cycles = 10;
        end

        `uvm_info(get_type_name(),
                  $sformatf("Apply reset for %0d cycles",
                            reset_cycles),
                  UVM_MEDIUM)

        //-----------------------------------------
        // Assert reset
        //-----------------------------------------

        vseqr.vif.i_rst_n <= 1'b0;

        repeat(reset_cycles)
            @(posedge vseqr.vif.i_clk);

        //-----------------------------------------
        // Release reset
        //-----------------------------------------

        vseqr.vif.i_rst_n <= 1'b1;

        //-----------------------------------------
        // Settle
        //-----------------------------------------

        repeat(5)
            @(posedge vseqr.vif.i_clk);

        `uvm_info(get_type_name(),
                  "Reset completed",
                  UVM_MEDIUM)

    endtask

endclass