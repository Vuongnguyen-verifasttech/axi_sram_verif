`timescale 1ns/1ps

class axi4_fixed_burst_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_fixed_burst_seq)

    int unsigned n_trans = 20;

    function new(string name = "axi4_fixed_burst_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_wr_seq_item   wr_req;
        axi4_rd_seq_item   rd_req;
        axi4_single_wr_seq wr_seq;
        axi4_single_rd_seq rd_seq;

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START FIXED Burst: %0d transactions", n_trans),
            UVM_LOW)

        repeat (n_trans) begin

            // ------------------------------------------------------------------
            // Write
            // ------------------------------------------------------------------
            wr_req = axi4_wr_seq_item::type_id::create("wr_req");

            if (!wr_req.randomize() with {
                    awburst == 2'b00;
                    awlen   inside {[1:15]};
                    awaddr  % 4 == 0;
                    wdata.size() == awlen + 1;
                })
                `uvm_fatal(get_type_name(), "WR Randomization failed")

            `uvm_info(get_type_name(),
                $sformatf("FIXED WR: AWADDR=0x%0h AWLEN=%0d BEATS=%0d (last beat wins)",
                          wr_req.awaddr, wr_req.awlen, wr_req.awlen + 1),
                UVM_MEDIUM)

            wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
            wr_seq.req = wr_req;
            wr_seq.start(vseqr.wr_seqr);

            // ------------------------------------------------------------------
            // Read — cùng địa chỉ, cùng số beat
            // ------------------------------------------------------------------
            rd_req = axi4_rd_seq_item::type_id::create("rd_req");

            if (!rd_req.randomize() with {
                    arburst == 2'b00;
                    arlen   == wr_req.awlen;   // đủ số beat để check cả 2 điều kiện
                    araddr  == wr_req.awaddr;
                })
                `uvm_fatal(get_type_name(), "RD Randomization failed")

            rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

            // ------------------------------------------------------------------
            // Checker 1: beat cuối write == tất cả beat read về (last beat wins)
            // Checker 2: tất cả beat read giống nhau (DUT không tăng địa chỉ)
            // ------------------------------------------------------------------
            begin
                logic [31:0] last_wdata;
                logic [31:0] first_rdata;
                bit check_pass;

                last_wdata  = wr_req.wdata[wr_req.awlen];  // beat cuối write
                first_rdata = rd_req.rdata[0];
                check_pass  = 1;

                // Checker 1: last beat write == rdata[0]
                if (first_rdata !== last_wdata) begin
                    check_pass = 0;
                    `uvm_error(get_type_name(),
                        $sformatf("FAIL [Last Beat Wins]: AWADDR=0x%0h last_wdata=0x%0h rdata[0]=0x%0h",
                                  wr_req.awaddr, last_wdata, first_rdata))
                end

                // Checker 2: tất cả beat read phải giống nhau
                foreach (rd_req.rdata[i]) begin
                    if (rd_req.rdata[i] !== first_rdata) begin
                        check_pass = 0;
                        `uvm_error(get_type_name(),
                            $sformatf("FAIL [Addr Not Fixed]: beat[%0d]=0x%0h != beat[0]=0x%0h — DUT đã tăng địa chỉ nội bộ",
                                      i, rd_req.rdata[i], first_rdata))
                    end
                end

                if (check_pass)
                    `uvm_info(get_type_name(),
                        $sformatf("PASS: AWADDR=0x%0h last_wdata=0x%0h | %0d read beats đều giống nhau",
                                  wr_req.awaddr, last_wdata, rd_req.rdata.size()),
                        UVM_MEDIUM)
            end

        end

        `uvm_info(get_type_name(), "DONE FIXED Burst", UVM_LOW)

    endtask

endclass : axi4_fixed_burst_seq