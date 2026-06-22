`timescale 1ns/1ps

class axi4_wrap_burst_test extends axi4_base_test;

    `uvm_component_utils(axi4_wrap_burst_test)

    function new(string name = "axi4_wrap_burst_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        axi4_wrap_burst_seq seq;

        phase.raise_objection(this);

        seq = axi4_wrap_burst_seq::type_id::create("seq");
        seq.start(env.virtual_seqr);

        phase.drop_objection(this);
    endtask

endclass : axi4_wrap_burst_test