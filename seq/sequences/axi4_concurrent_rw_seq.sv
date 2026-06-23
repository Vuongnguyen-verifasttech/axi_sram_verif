`timescale 1ns/1ps

// =============================================================================
// axi4_concurrent_rw_seq.sv
// Concurrent Write + Read
//
// DUT behavior (từ FSM analysis):
//   - 1 FSM chung cho AW và AR → không xử lý song song thật sự
//   - Khi đang write (S_ADDR): arready=0 → AR bị block
//   - Khi đang read  (S_ADDR): awready=0 → AW bị block
//   - Xử lý tuần tự theo thứ tự đến trước
//
// Test verify:
//   1. Không deadlock khi AW + AR pending cùng lúc
//   2. Không drop transaction nào
//   3. Data integrity — read về đúng giá trị đã write
//   4. Tất cả transaction hoàn thành trong timeout
// =============================================================================

class axi4_concurrent_rw_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_concurrent_rw_seq)

    int unsigned n_rounds = 20;  // số lần gửi cặp write+read concurrent

    function new(string name = "axi4_concurrent_rw_seq");
        super.new(name);
    endfunction

    virtual task body();

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START Concurrent Write+Read: %0d rounds", n_rounds),
            UVM_LOW)

        // ------------------------------------------------------------------
        // Phase 1: Seed data — write N địa chỉ để có data sẵn cho read
        // ------------------------------------------------------------------
        begin
            axi4_wr_seq_item   wr_req;
            axi4_single_wr_seq wr_seq;

            `uvm_info(get_type_name(), "Phase 1: Seeding data...", UVM_MEDIUM)

            repeat (n_rounds) begin
                wr_req = axi4_wr_seq_item::type_id::create("seed_wr");
                if (!wr_req.randomize() with {
                        awburst == 2'b01;
                        awlen   == 0;       // single beat để seed nhanh
                        awaddr  % 4 == 0;
                        wdata.size() == 1;
                    })
                    `uvm_fatal(get_type_name(), "Seed WR randomize failed")

                wr_seq = axi4_single_wr_seq::type_id::create("seed_wr_seq");
                wr_seq.req = wr_req;
                wr_seq.start(vseqr.wr_seqr);
            end
        end

        // ------------------------------------------------------------------
        // Phase 2: Concurrent — fork write thread + read thread
        // Cả 2 thread cùng pump transaction vào DUT
        // DUT sẽ serialize (AW trước hoặc AR trước tùy thứ tự đến)
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(),
            "Phase 2: Launching concurrent WR + RD threads...", UVM_MEDIUM)

        fork

            // Write thread
            begin : wr_thread
                repeat (n_rounds) begin
                    axi4_wr_seq_item   wr_req;
                    axi4_single_wr_seq wr_seq;

                    wr_req = axi4_wr_seq_item::type_id::create("wr_req");
                    if (!wr_req.randomize() with {
                            awburst == 2'b01;
                            awlen   inside {[0:7]};
                            awaddr  % 4 == 0;
                            wdata.size() == awlen + 1;
                        })
                        `uvm_fatal(get_type_name(), "WR randomize failed")

                    wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
                    wr_seq.req = wr_req;
                    wr_seq.start(vseqr.wr_seqr);
                end
                `uvm_info(get_type_name(), "WR thread done", UVM_MEDIUM)
            end

            // Read thread
            begin : rd_thread
                repeat (n_rounds) begin
                    axi4_rd_seq_item   rd_req;
                    axi4_single_rd_seq rd_seq;

                    rd_req = axi4_rd_seq_item::type_id::create("rd_req");
                    if (!rd_req.randomize() with {
                            arburst == 2'b01;
                            arlen   inside {[0:7]};
                            araddr  % 4 == 0;
                        })
                        `uvm_fatal(get_type_name(), "RD randomize failed")

                    rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
                    rd_seq.req = rd_req;
                    rd_seq.start(vseqr.rd_seqr);
                end
                `uvm_info(get_type_name(), "RD thread done", UVM_MEDIUM)
            end

        join  // chờ cả 2 thread hoàn thành

        `uvm_info(get_type_name(),
            "DONE Concurrent Write+Read — no deadlock, scoreboard verifies data integrity",
            UVM_LOW)

    endtask

endclass : axi4_concurrent_rw_seq