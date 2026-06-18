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
        event               e_watch_done;

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
        // Fork: drive burst | monitor beat & inject reset at beat index 2
        //       | watch for ANY beat appearing WHILE reset is asserted
        //       (đo đồng thời, không phải sau khi rst_seq.start() return —
        //       vì driver chạy độc lập, disable fork không ảnh hưởng tới nó)
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
                            $sformatf("W beat index %0d completed", beat_count_before_reset - 1),
                            UVM_HIGH)

                        // Sau khi beat index 2 hoàn thành (beat0,1,2 = 3 beat), inject reset
                        if (beat_count_before_reset == 3 && !reset_injected) begin
                            reset_injected = 1'b1;
                            `uvm_info(get_type_name(),
                                "Injecting reset right after beat index 2",
                                UVM_LOW)
                            rst_seq.start(vseqr);
                        end
                    end
                end
            end

            begin : watch_spurious_beats_during_reset
                // Chờ reset_injected lên 1, rồi theo dõi i_rst_n SONG SONG
                // với việc beat có tiếp tục xuất hiện không — đây là check
                // thật, không phải check "sau khi reset xong" như trước.
                //
                // Đây là thread QUYẾT ĐỊNH kết quả test — disable fork phải
                // chờ thread này hoàn thành (rst_n deassert), không phải
                // dừng sớm khi drive_burst hoặc monitor_and_inject_reset
                // xong trước (vd: nếu DUT có bug y như log thật, burst vẫn
                // chạy hết 16 beat trước khi rst_n deassert).
                wait (reset_injected == 1'b1);

                forever begin
                    @(posedge vseqr.vif.i_clk);
                    if (vseqr.vif.i_rst_n === 1'b0) begin
                        // Đang trong giai đoạn reset active
                        if (vseqr.vif.wvalid && vseqr.vif.wready) begin
                            beat_count_after_reset++;
                            `uvm_error(get_type_name(),
                                $sformatf("FAIL: W beat xuất hiện trong lúc rst_n=0 (beat count=%0d)",
                                          beat_count_after_reset))
                        end
                    end
                    else begin
                        // rst_n đã deassert — dừng theo dõi, kết thúc thread này
                        -> e_watch_done;
                        break;
                    end
                end
            end

        join_none

        // Chờ đúng cờ báo "watch_spurious_beats_during_reset" hoàn thành,
        // không dùng join_any (tránh cắt sớm nếu drive_burst hoặc
        // monitor_and_inject_reset xong trước, đặc biệt khi DUT có bug
        // khiến burst chạy hết 16 beat bất chấp reset).
        @e_watch_done;
        disable fork;

        // Settle vài cycle trước khi check idle state (vì disable fork có
        // thể cắt ngay tại thời điểm rst_n vừa deassert)
        repeat (5) @(posedge vseqr.vif.i_clk);

        //-----------------------------------------------------------------
        // Đánh giá kết quả: beat_count_after_reset đã được đo ĐỒNG THỜI
        // với reset active (trong fork ở trên), không phải đo sau khi
        // rst_seq.start() return — vì driver chạy độc lập với sequence.
        //-----------------------------------------------------------------
        if (beat_count_after_reset != 0)
            `uvm_error(get_type_name(),
                $sformatf("FAIL: %0d beat(s) xuất hiện khi rst_n=0 (DUT không abort burst khi reset)",
                          beat_count_after_reset))
        else
            `uvm_info(get_type_name(),
                "PASS: không có W beat nào xuất hiện trong lúc reset active",
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