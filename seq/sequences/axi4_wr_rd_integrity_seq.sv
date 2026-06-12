`timescale 1ns/1ps

class axi4_wr_rd_integrity_seq extends uvm_sequence;

    `uvm_object_utils(axi4_wr_rd_integrity_seq)

    axi4_virtual_seqr vseqr;

    int unsigned num_transactions = 100;

    function new(string name="axi4_wr_rd_integrity_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_single_wr_seq wr_seq;
        axi4_single_rd_seq rd_seq;

        axi4_wr_seq_item wr_item;
        axi4_rd_seq_item rd_item;

        if(!$cast(vseqr,m_sequencer))
            `uvm_fatal(get_type_name(),
                       "Cannot cast virtual sequencer")

        repeat(num_transactions)
        begin

            //-----------------------------------------
            // WRITE
            //-----------------------------------------

            wr_item =
                axi4_wr_seq_item::type_id::create("wr_item");

            if(!wr_item.randomize())
                `uvm_fatal(get_type_name(),
                           "WR randomization failed")

            wr_seq =
                axi4_single_wr_seq::type_id::create("wr_seq");

            wr_seq.req = wr_item;

            wr_seq.start(vseqr.wr_seqr);

            //-----------------------------------------
            // READ SAME LOCATION
            //-----------------------------------------

            rd_item =
                axi4_rd_seq_item::type_id::create("rd_item");

            if(!rd_item.randomize() with {

                araddr  == wr_item.awaddr;
                arlen   == wr_item.awlen;
                arburst == wr_item.awburst;
                arid    == wr_item.awid;

            })
                `uvm_fatal(get_type_name(),
                           "RD randomization failed")

            rd_seq =
                axi4_single_rd_seq::type_id::create("rd_seq");

            rd_seq.req = rd_item;

            rd_seq.start(vseqr.rd_seqr);

            `uvm_info(get_type_name(),
                $sformatf(
                "Integrity WR->RD addr=0x%0h beats=%0d",
                wr_item.awaddr,
                wr_item.awlen + 1),
                UVM_LOW)

        end

    endtask

endclass