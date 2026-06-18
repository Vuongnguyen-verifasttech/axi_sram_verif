`timescale 1ns/1ps

// =============================================================================
// axi4_reset_during_burst_seq.sv
// AXI_04 - Reset During Burst
//
// Drive 1 burst write 16 beat (awlen=15), chờ qua beat2 (3 beat đã hoàn
// thành trên W channel), rồi inject reset. Check không còn beat3..beat15
// xuất hiện trên W channel sau reset.
//
// Cách đếm beat: theo dõi vseqr.vif.wvalid && wready (handshake thật,
// không đếm theo clock đơn thuần vì có thể có wait-state).
// =============================================================================

class axi4_reset_during_burst_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_reset_during_burst_seq)

    function new(string name = "axi4_reset_during_burst_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_wr_seq_item   req;
        axi4_reset_seq      rst_seq;
        int unsigned        beat_count_before_reset;
        int unsigned        beat_count_after_reset;
        bit                 reset_injected;

        super.body();

        //-----------------------------------------------------------------
        // Build 1 burst write item: 16 beat (awlen=15), INCR
        //-----------------------------------------------------------------
        req = axi4_wr_seq_item::type_id::create("req");

        if (!req.randomize() with {
                awlen   == 8'd15;
                awburst == 2'b01;   // INCR
            })
            `uvm_fatal(get_type_name(), "Randomization failed for burst item")

        beat_count_before_reset = 0;
        beat_count_after_reset  = 0;
        reset_injected          = 1'b0;

        rst_seq = axi4_reset_seq::type_id::create("rst_seq");

        //-----------------------------------------------------------------
        // Fork: drive burst | monitor W handshake & inject reset at beat 3
        //-----------------------------------------------------------------
        fork

            begin : drive_burst
                axi4_single_wr_seq wr_seq;
                wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
                wr_seq.req = req;
                wr_seq.start(vseqr.wr_seqr);
            end

            begin : monitor_and_inject_reset
                forever begin
                    @(posedge vseqr.vif.i_clk);
                    if (vseqr.vif.wvalid && vseqr.vif.wready) begin
                        beat_count_before_reset++;
                        `uvm_info(get_type_name(),
                            $sformatf("W beat %0d completed", beat_count_before_reset),
                            UVM_HIGH)

                        // Sau khi 3 beat đã hoàn thành (beat0,1,2), inject reset
                        if (beat_count_before_reset == 3 && !reset_injected) begin
                            reset_injected = 1'b1;
                            `uvm_info(get_type_name(),
                                "Injecting reset after beat 2 (3 beats done)",
                                UVM_LOW)
                            rst_seq.start(vseqr);
                            break;
                        end
                    end
                end
            end

        join_any
        disable fork;

        //-----------------------------------------------------------------
        // Post-reset: count any further W beat appearing — phải = 0
        //-----------------------------------------------------------------
        repeat (20) begin
            @(posedge vseqr.vif.i_clk);
            if (vseqr.vif.wvalid && vseqr.vif.wready)
                beat_count_after_reset++;
        end

        if (beat_count_after_reset != 0)
            `uvm_error(get_type_name(),
                $sformatf("FAIL: %0d beat(s) appeared after reset (expected 0, beat3..beat15 must NOT occur)",
                          beat_count_after_reset))
        else
            `uvm_info(get_type_name(),
                "PASS: no W beat appeared after reset (beat3..beat15 correctly suppressed)",
                UVM_LOW)

        //-----------------------------------------------------------------
        // Idle-state checks giống reset_during_write
        //-----------------------------------------------------------------
        if (vseqr.vif.awready !== 1'b1)
            `uvm_error(get_type_name(), "AWREADY is not HIGH after reset")

        if (vseqr.vif.bvalid !== 1'b0)
            `uvm_error(get_type_name(), "Unexpected BVALID after reset")

        if (vseqr.vif.wfifo_empty !== 1'b1)
            `uvm_error(get_type_name(), "W FIFO not empty after reset")

        if (vseqr.vif.awfifo_empty !== 1'b1)
            `uvm_error(get_type_name(), "AW FIFO not empty after reset")

        if (vseqr.vif.bfifo_empty !== 1'b1)
            `uvm_error(get_type_name(), "B FIFO not empty after reset")

        `uvm_info(get_type_name(), "Reset during burst test finished", UVM_LOW)

    endtask

endclass : axi4_reset_during_burst_seq