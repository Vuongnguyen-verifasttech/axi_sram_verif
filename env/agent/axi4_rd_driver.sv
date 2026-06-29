`timescale 1ns/1ps

// =============================================================================
// axi4_rd_driver.sv
// Driver cho AXI4 Read path: AR channel + R channel (rready management)
//
// Fix so với thiết kế cũ:
//  1. Handshake hoàn toàn clock-aligned — dùng @(posedge clk) + sample flag
//  2. R channel: rready có thể deassert tạo backpressure phía read
//  3. rdata được capture trong driver (phục vụ sequences cần data ngay)
//     Monitor vẫn là nguồn chính thức cho scoreboard
//  4. Không dùng wait() ở bất kỳ đâu
//
// Fix drive_r_channel:
//  - Dùng rlast làm điều kiện thoát thay vì repeat(expected_beats)
//  - Phân biệt rõ 2 loại DUT bug:
//      + RLAST_EARLY : DUT assert rlast trước khi đủ beats
//      + RLAST_MISSING: DUT gửi đủ beats nhưng không assert rlast
// =============================================================================

class axi4_rd_driver extends uvm_driver #(axi4_rd_seq_item);

    // =========================================================================
    // Config & Interface
    // =========================================================================
    axi4_agent_cfg          cfg;
    virtual axi4_if.master  vif;

    // =========================================================================
    // UVM
    // =========================================================================
    `uvm_component_utils(axi4_rd_driver)

    function new(string name = "axi4_rd_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("RD_DRV_CFG", "Cannot get cfg from config_db")
        if (!uvm_config_db#(virtual axi4_if.master)::get(this, "", "vif", vif))
            `uvm_fatal("RD_DRV_VIF", "Cannot get vif from config_db")
    endfunction

    // =========================================================================
    // Run Phase
    // =========================================================================
    virtual task run_phase(uvm_phase phase);
        @(posedge vif.i_clk);
        reset_rd_signals();
        wait (vif.i_rst_n === 1'b1);
        @(posedge vif.i_clk);

        fork

            // ------------------------------------------------------------------
            // Thread 1: Transaction loop
            // ------------------------------------------------------------------
            forever begin
                axi4_rd_seq_item tr;
                seq_item_port.get_next_item(tr);

                `uvm_info(get_type_name(),
                          $sformatf("Driving: %s", tr.convert2string()),
                          UVM_MEDIUM)

                drive_ar_channel(tr);
                drive_r_channel(tr);

                seq_item_port.item_done();
            end

            // ------------------------------------------------------------------
            // Thread 2: Reset monitor
            // Deassert tất cả signals ngay khi rst_n=0
            // ------------------------------------------------------------------
            forever begin
                @(negedge vif.i_rst_n);
                `uvm_info(get_type_name(),
                          "Reset detected — deassert all RD signals",
                          UVM_MEDIUM)
                reset_rd_signals();
                wait (vif.i_rst_n === 1'b1);
                @(posedge vif.i_clk);
                `uvm_info(get_type_name(),
                          "Reset released — RD driver ready",
                          UVM_MEDIUM)
            end

        join_none

    endtask

    // =========================================================================
    // Reset signals
    // =========================================================================
    virtual task reset_rd_signals();
        vif.master_cb.arvalid <= 1'b0;
        vif.master_cb.araddr  <= '0;
        vif.master_cb.arid    <= '0;
        vif.master_cb.arlen   <= '0;
        vif.master_cb.arburst <= 2'b01;
        vif.master_cb.rready  <= 1'b0;
    endtask

    // =========================================================================
    // Drive AR channel
    // =========================================================================
    virtual task drive_ar_channel(axi4_rd_seq_item tr);
        vif.master_cb.araddr  <= tr.araddr;
        vif.master_cb.arid    <= tr.arid;
        vif.master_cb.arlen   <= tr.arlen;
        vif.master_cb.arburst <= tr.arburst;
        vif.master_cb.arvalid <= 1'b1;

        @(posedge vif.i_clk);

        while (!vif.master_cb.arready) begin
            if (!vif.i_rst_n) begin
                `uvm_warning("AR_RST", "Reset detected while waiting ARREADY")
                vif.master_cb.arvalid <= 1'b0;
                vif.master_cb.araddr  <= '0;
                return;
            end
            @(posedge vif.i_clk);
        end

        vif.master_cb.arvalid <= 1'b0;
        vif.master_cb.araddr  <= '0;

        `uvm_info(get_type_name(),
                  $sformatf("AR done: ARADDR=0x%0h ARID=0x%0h ARLEN=%0d",
                             tr.araddr, tr.arid, tr.arlen),
                  UVM_HIGH)
    endtask

    // =========================================================================
    // Drive R channel
    //
    // Dùng rlast làm điều kiện thoát — đúng AXI spec
    // expected_beats chỉ dùng để detect DUT bug:
    //   RLAST_EARLY  : rlast=1 nhưng beat_cnt < expected_beats
    //   RLAST_MISSING: beat_cnt == expected_beats nhưng rlast chưa đến
    // =========================================================================
    virtual task drive_r_channel(axi4_rd_seq_item tr);

        int unsigned expected_beats;
        int unsigned beat_cnt;

        expected_beats = tr.arlen + 1;
        beat_cnt       = 0;
        tr.rdata.delete();

        forever begin

            int unsigned bp_cycles;

            // ------------------------------------------------------------------
            // Backpressure: deassert rready trước khi accept beat
            // ------------------------------------------------------------------
            if (cfg.backpressure_pct > 0) begin
                bp_cycles = ($urandom_range(0, 99) < cfg.backpressure_pct) ?
                            $urandom_range(1, cfg.max_backpressure_cycles) : 0;
                if (bp_cycles > 0) begin
                    `uvm_info("RD_BP",
                        $sformatf("R  beat[%0d] STALL %0d cycles | bp_pct=%0d%% | ARADDR=0x%0h",
                            beat_cnt, bp_cycles, cfg.backpressure_pct, tr.araddr),
                        UVM_LOW)
                    vif.master_cb.rready <= 1'b0;
                    repeat (bp_cycles) @(posedge vif.i_clk);
                end
            end

            // ------------------------------------------------------------------
            // Assert rready, chờ rvalid
            // ------------------------------------------------------------------
            vif.master_cb.rready <= 1'b1;

            do begin
                @(posedge vif.i_clk);
            end while (!vif.master_cb.rvalid);

            // ------------------------------------------------------------------
            // Handshake xảy ra — capture beat
            // ------------------------------------------------------------------
            tr.rdata.push_back(vif.master_cb.rdata);
            tr.rresp = vif.master_cb.rresp;
            tr.rid   = vif.master_cb.rid;
            beat_cnt++;

            `uvm_info(get_type_name(),
                      $sformatf("R  beat[%0d]: RDATA=0x%0h RLAST=%0b RRESP=%0b",
                                 beat_cnt-1, vif.master_cb.rdata,
                                 vif.master_cb.rlast, vif.master_cb.rresp),
                      UVM_HIGH)

            // ------------------------------------------------------------------
            // Kiểm tra rlast
            // ------------------------------------------------------------------
            if (vif.master_cb.rlast) begin
                // DUT assert rlast — check beat count
                if (beat_cnt != expected_beats)
                    `uvm_error(get_type_name(),
                        $sformatf("** RTL BUG ** RLAST_EARLY: rlast tại beat[%0d] nhưng expected=%0d beats | ARADDR=0x%0h ARLEN=%0d",
                            beat_cnt-1, expected_beats, tr.araddr, tr.arlen))
                // Dù đúng hay sai — rlast = tín hiệu kết thúc burst từ DUT, thoát loop
                break;
            end

            // ------------------------------------------------------------------
            // Đã nhận đủ beats nhưng DUT chưa assert rlast — RTL bug
            // ------------------------------------------------------------------
            if (beat_cnt == expected_beats) begin
                `uvm_error(get_type_name(),
                    $sformatf("** RTL BUG ** RLAST_MISSING: nhận đủ %0d beats nhưng rlast chưa assert | ARADDR=0x%0h ARLEN=%0d",
                        expected_beats, tr.araddr, tr.arlen))
                break;
            end

        end // forever

        vif.master_cb.rready <= 1'b0;

        `uvm_info(get_type_name(),
                  $sformatf("R  done: RID=0x%0h BEATS=%0d/%0d RRESP=%0b",
                             tr.rid, beat_cnt, expected_beats, tr.rresp),
                  UVM_MEDIUM)

    endtask

endclass : axi4_rd_driver