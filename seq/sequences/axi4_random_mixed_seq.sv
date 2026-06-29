`timescale 1ns/1ps

// =============================================================================
// axi4_random_mixed_seq.sv
// AXI_19 - Mixed Random Traffic
//
// Random hoàn toàn: burst type (INCR/FIXED/WRAP), len, addr, order write/read
// Target: data integrity đúng, không deadlock, coverage cao
// =============================================================================

class axi4_random_mixed_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_random_mixed_seq)

    int unsigned n_trans = 50;

    function new(string name = "axi4_random_mixed_seq");
        super.new(name);
    endfunction

    virtual task body();

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START Mixed Random Traffic: %0d transactions", n_trans),
            UVM_LOW)

        repeat (n_trans) begin

            axi4_wr_seq_item   wr_req;
            axi4_rd_seq_item   rd_req;
            axi4_single_wr_seq wr_seq;
            axi4_single_rd_seq rd_seq;
            int unsigned       op;

            // Random: 0=write only, 1=read only, 2=write then read
            op = $urandom_range(0, 2);

            // ------------------------------------------------------------------
            // Write
            // ------------------------------------------------------------------
            if (op == 0 || op == 2) begin

                wr_req = axi4_wr_seq_item::type_id::create("wr_req");

                // Để solver random hoàn toàn theo constraint của seq_item
                // Chỉ override WRAP constraint (awlen phải thuộc {1,3,7,15})
                if (!wr_req.randomize() with {
                        if (awburst == 2'b10) {
                            awlen inside {1, 3, 7, 15};
                            awaddr % ((awlen + 1) * 4) == 0;
                        }
                        wdata.size() == awlen + 1;
                    })
                    `uvm_fatal(get_type_name(), "WR randomize failed")

                wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
                wr_seq.req = wr_req;
                wr_seq.start(vseqr.wr_seqr);

            end

            // ------------------------------------------------------------------
            // Read — nếu op==2: read cùng địa chỉ vừa write
            //        nếu op==1: read random
            // ------------------------------------------------------------------
            if (op == 1 || op == 2) begin

                rd_req = axi4_rd_seq_item::type_id::create("rd_req");

                if (op == 2) begin
                    // Read lại đúng địa chỉ vừa write → scoreboard có meaningful check
                    if (!rd_req.randomize() with {
                            arburst == wr_req.awburst;
                            arlen   == wr_req.awlen;
                            araddr  == wr_req.awaddr;
                        })
                        `uvm_fatal(get_type_name(), "RD randomize failed")
                end else begin
                    // Read random hoàn toàn
                    if (!rd_req.randomize() with {
                            if (arburst == 2'b10) {
                                arlen inside {1, 3, 7, 15};
                                araddr % ((arlen + 1) * 4) == 0;
                            }
                        })
                        `uvm_fatal(get_type_name(), "RD randomize failed")
                end

                rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
                rd_seq.req = rd_req;
                rd_seq.start(vseqr.rd_seqr);

            end

        end

        `uvm_info(get_type_name(), "DONE Mixed Random Traffic", UVM_LOW)

    endtask

endclass : axi4_random_mixed_seq