`timescale 1ns/1ps

class axi4_concurrent_rw_bug_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_concurrent_rw_bug_seq)

    int unsigned n_rounds = 20;

    function new(string name = "axi4_concurrent_rw_bug_seq");
        super.new(name);
    endfunction

    virtual task body();

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START Concurrent WR+RD: %0d rounds — target: no deadlock", n_rounds),
            UVM_LOW)

        fork

            begin : wr_thread
                repeat (n_rounds) begin
                    axi4_wr_seq_item   wr_req;
                    axi4_single_wr_seq wr_seq;

                    wr_req = axi4_wr_seq_item::type_id::create("wr_req");
                    if (!wr_req.randomize())
                        `uvm_fatal(get_type_name(), "WR randomize failed")

                    wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
                    wr_seq.req = wr_req;
                    wr_seq.start(vseqr.wr_seqr);
                end
                `uvm_info(get_type_name(), "WR thread done", UVM_MEDIUM)
            end

            begin : rd_thread
                repeat (n_rounds) begin
                    axi4_rd_seq_item   rd_req;
                    axi4_single_rd_seq rd_seq;

                    rd_req = axi4_rd_seq_item::type_id::create("rd_req");
                    if (!rd_req.randomize())
                        `uvm_fatal(get_type_name(), "RD randomize failed")

                    rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
                    rd_seq.req = rd_req;
                    rd_seq.start(vseqr.rd_seqr);

                    // Delay nhỏ để RD thread không chạy nhanh hơn WR thread quá nhiều
                    // Tránh trường hợp RD done sớm → burst write cuối không có read peer
                    repeat ($urandom_range(1, 5)) @(posedge vseqr.vif.i_clk);
                end
                `uvm_info(get_type_name(), "RD thread done", UVM_MEDIUM)
            end

        join

        `uvm_info(get_type_name(), "DONE — no deadlock detected", UVM_LOW)

    endtask

endclass : axi4_concurrent_rw_bug_seq