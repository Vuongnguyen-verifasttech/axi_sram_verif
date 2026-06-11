class axi4_wr_rd_test extends axi4_base_test;

    axi4_wr_base_seq wr_seq;
    axi4_rd_base_seq rd_seq;

    virtual task run_phase(uvm_phase phase);

        phase.raise_objection(this);

        wr_seq = axi4_wr_base_seq::type_id::create("wr_seq");
        rd_seq = axi4_rd_base_seq::type_id::create("rd_seq");

        wr_seq.num_transactions = 20;
        rd_seq.num_transactions = 20;

        wr_seq.start(env.agent.wr_seqr);

        #100ns;

        rd_seq.start(env.agent.rd_seqr);

        phase.drop_objection(this);

    endtask

endclass