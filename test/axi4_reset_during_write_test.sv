class axi4_reset_during_write_test extends axi4_base_test;

`uvm_component_utils(axi4_reset_during_write_test)

function new(string name = "axi4_reset_during_write_test",
             uvm_component parent = null);
    super.new(name, parent);
endfunction

virtual task run_phase(uvm_phase phase);

    axi4_reset_during_write_seq seq;

    phase.raise_objection(this);

    seq = axi4_reset_during_write_seq::type_id::create("seq");

    seq.start(env.virtual_seqr);

    phase.drop_objection(this);

endtask


endclass
