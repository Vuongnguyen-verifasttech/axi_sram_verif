`timescale 1ns/1ps

// =============================================================================
// axi4_random_reset_stress_seq.sv
// AXI_05 - Random Reset Stress
//
// Mục tiêu:
//   - Reset xuất hiện ngẫu nhiên trong khi traffic (write + read) đang chạy
//   - Reset có thể rơi vào bất kỳ channel nào: AW, W, B, AR, R
//   - Sau mỗi reset, DUT phải:
//       1. Recovery (awready/wready/arready trở về idle, bvalid/rvalid = 0)
//       2. Không deadlock (transaction mới sau reset phải hoàn thành)
//       3. Không spurious response (bvalid/rvalid không được lên trong khi rst_n=0)
//
// Flow tổng quát:
//   - traffic_thread: liên tục gửi random write + read (dùng virtual seqr)
//   - reset_thread: sau mỗi random_delay (min..max), inject 1 lần reset
//   - check_thread: giám sát toàn bộ thời gian, báo lỗi ngay khi thấy
//                   response spurious trong lúc rst_n = 0
//   - Sau N lần reset: dừng traffic, chờ recovery, verify idle state,
//     gửi 1 write + 1 read để xác nhận DUT không bị deadlock
//
// =============================================================================

class axi4_random_reset_stress_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_random_reset_stress_seq)

    // =========================================================================
    // Knobs — có thể override từ test
    // =========================================================================
    int unsigned num_resets         = 5;    // Số lần inject reset
    int unsigned min_delay_ns       = 50;   // Delay tối thiểu giữa các lần reset (ns)
    int unsigned max_delay_ns       = 500;  // Delay tối đa
    int unsigned reset_duration_ns  = 30;   // Độ dài mỗi lần reset (ns, phải >= 2 chu kỳ clk)
    int unsigned post_reset_settle  = 10;   // Số clk chờ sau deassert trước khi check idle

    // =========================================================================
    // Internal tracking
    // =========================================================================
    int unsigned reset_count;
    int unsigned spurious_bvalid_count;
    int unsigned spurious_rvalid_count;
    event        e_all_resets_done;
    event        e_traffic_stop;

    // =========================================================================
    function new(string name = "axi4_random_reset_stress_seq");
        super.new(name);
    endfunction

    // =========================================================================
    // Body
    // =========================================================================
    virtual task body();

        axi4_reset_seq rst_seq;

        super.body();

        reset_count            = 0;
        spurious_bvalid_count  = 0;
        spurious_rvalid_count  = 0;

        `uvm_info(get_type_name(),
            $sformatf("START Random Reset Stress: %0d resets, delay %0d..%0d ns, rst_dur=%0d ns",
                      num_resets, min_delay_ns, max_delay_ns, reset_duration_ns),
            UVM_LOW)

        // =====================================================================
        // fork 3 threads
        // =====================================================================
        fork

            // ------------------------------------------------------------------
            // Thread 1: TRAFFIC — liên tục gửi write + read cho đến khi
            //           e_traffic_stop được trigger (sau N reset xong)
            // ------------------------------------------------------------------
            begin : traffic_thread
                forever begin
                    axi4_single_wr_seq wr_seq;
                    axi4_single_rd_seq rd_seq;

                    // Kiểm tra nếu được yêu cầu dừng thì exit
                    if (e_traffic_stop.triggered) break;

                    // Random write
                    wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
                    wr_seq.start(vseqr.wr_seqr);

                    if (e_traffic_stop.triggered) break;

                    // Random read
                    rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
                    rd_seq.start(vseqr.rd_seqr);
                end
            end

            // ------------------------------------------------------------------
            // Thread 2: RESET INJECTION — inject N lần reset, mỗi lần cách
            //           nhau 1 khoảng delay ngẫu nhiên
            // ------------------------------------------------------------------
            begin : reset_thread
                repeat (num_resets) begin
                    int unsigned delay_ns;
                    delay_ns = $urandom_range(min_delay_ns, max_delay_ns);

                    `uvm_info(get_type_name(),
                        $sformatf("[Reset %0d/%0d] Waiting %0d ns before inject",
                                  reset_count + 1, num_resets, delay_ns),
                        UVM_MEDIUM)

                    // Delay ngẫu nhiên — reset có thể rơi vào AW/W/B/AR/R
                    #(delay_ns);

                    reset_count++;
                    `uvm_info(get_type_name(),
                        $sformatf("[Reset %0d/%0d] INJECT reset now @ %0t",
                                  reset_count, num_resets, $time),
                        UVM_LOW)

                    // Dùng rst_seq nếu có, hoặc drive trực tiếp qua vif
                    // (tương tự pattern trong reset_during_burst_seq)
                    rst_seq = axi4_reset_seq::type_id::create("rst_seq");
                    rst_seq.start(vseqr);

                    // Chờ vài chu kỳ sau deassert trước khi inject tiếp
                    repeat (post_reset_settle) @(posedge vseqr.vif.i_clk);

                    // Check idle state ngay sau mỗi lần reset
                    check_idle_state(reset_count);
                end

                // Báo cho traffic dừng
                -> e_traffic_stop;
                -> e_all_resets_done;
            end

            // ------------------------------------------------------------------
            // Thread 3: SPURIOUS CHECK — giám sát liên tục trong suốt test,
            //           báo lỗi ngay khi có response xuất hiện trong lúc rst_n=0
            //
            // Đây là thread QUAN TRỌNG NHẤT — bắt deadlock và protocol violation
            // DUT KHÔNG ĐƯỢC assert bvalid/rvalid khi rst_n = 0
            // ------------------------------------------------------------------
            begin : check_thread
                forever begin
                    @(posedge vseqr.vif.i_clk);

                    if (e_all_resets_done.triggered) break;

                    if (vseqr.vif.i_rst_n === 1'b0) begin

                        // Check BVALID spurious
                        if (vseqr.vif.bvalid === 1'b1) begin
                            spurious_bvalid_count++;
                            `uvm_error(get_type_name(),
                                $sformatf("FAIL: BVALID=1 khi rst_n=0 (lần %0d, @ %0t)",
                                          spurious_bvalid_count, $time))
                        end

                        // Check RVALID spurious
                        if (vseqr.vif.rvalid === 1'b1) begin
                            spurious_rvalid_count++;
                            `uvm_error(get_type_name(),
                                $sformatf("FAIL: RVALID=1 khi rst_n=0 (lần %0d, @ %0t)",
                                          spurious_rvalid_count, $time))
                        end

                        // Check AWREADY phải về 0 khi reset (DUT đang reset nội bộ)
                        // Một số DUT giữ awready=1 theo thiết kế — comment out nếu DUT của bạn như vậy
                        if (vseqr.vif.awready === 1'b1)
                            `uvm_info(get_type_name(),
                                $sformatf("NOTE: AWREADY=1 khi rst_n=0 @ %0t (check DUT spec)", $time),
                                UVM_HIGH)

                    end
                end
            end

        join_none

        // Chờ tất cả reset xong (reset_thread trigger e_all_resets_done)
        @e_all_resets_done;

        // Drain traffic thread
        disable fork;

        // Settle thêm trước final check
        repeat (post_reset_settle) @(posedge vseqr.vif.i_clk);

        // =====================================================================
        // DEADLOCK CHECK — gửi 1 write + 1 read sau toàn bộ reset, DUT phải
        // hoàn thành bình thường (không hang). Timeout watchdog trong
        // tb_top.sv sẽ bắt nếu DUT bị deadlock thật.
        // =====================================================================
        begin : post_stress_sanity
            axi4_single_wr_seq wr_seq;
            axi4_single_rd_seq rd_seq;

            `uvm_info(get_type_name(),
                "POST-STRESS SANITY: Sending 1 write + 1 read after all resets",
                UVM_LOW)

            wr_seq = axi4_single_wr_seq::type_id::create("post_wr");
            wr_seq.start(vseqr.wr_seqr);

            rd_seq = axi4_single_rd_seq::type_id::create("post_rd");
            rd_seq.start(vseqr.rd_seqr);

            `uvm_info(get_type_name(),
                "POST-STRESS SANITY: PASS — DUT không bị deadlock sau stress reset",
                UVM_LOW)
        end

        // =====================================================================
        // Tổng kết
        // =====================================================================
        `uvm_info(get_type_name(),
            $sformatf("SUMMARY: %0d resets injected | spurious BVALID=%0d | spurious RVALID=%0d",
                      reset_count,
                      spurious_bvalid_count,
                      spurious_rvalid_count),
            UVM_LOW)

        if (spurious_bvalid_count == 0 && spurious_rvalid_count == 0)
            `uvm_info(get_type_name(), "PASS: Random Reset Stress PASSED", UVM_LOW)
        else
            `uvm_error(get_type_name(),
                $sformatf("FAIL: %0d spurious response(s) detected during reset",
                          spurious_bvalid_count + spurious_rvalid_count))

    endtask

    // =========================================================================
    // Task: check idle state sau mỗi lần reset
    // Gọi sau khi rst_n đã deassert + settle đủ cycle
    // =========================================================================
    virtual task check_idle_state(int unsigned reset_idx);

        `uvm_info(get_type_name(),
            $sformatf("[Reset %0d] Checking idle state...", reset_idx),
            UVM_MEDIUM)

        // AW channel: DUT phải sẵn sàng nhận transaction mới
        if (vseqr.vif.awready !== 1'b1)
            `uvm_error(get_type_name(),
                $sformatf("[Reset %0d] FAIL: AWREADY not HIGH after reset", reset_idx))

        // AR channel
        if (vseqr.vif.arready !== 1'b1)
            `uvm_error(get_type_name(),
                $sformatf("[Reset %0d] FAIL: ARREADY not HIGH after reset", reset_idx))

        // B channel: không có response nào đang treo
        if (vseqr.vif.bvalid !== 1'b0)
            `uvm_error(get_type_name(),
                $sformatf("[Reset %0d] FAIL: BVALID not LOW after reset (spurious B response)", reset_idx))

        // R channel: không có data nào đang treo
        if (vseqr.vif.rvalid !== 1'b0)
            `uvm_error(get_type_name(),
                $sformatf("[Reset %0d] FAIL: RVALID not LOW after reset (spurious R response)", reset_idx))

        // Internal FIFO check (nếu interface expose signal này)
        if (vseqr.vif.awfifo_empty !== 1'b1)
            `uvm_error(get_type_name(),
                $sformatf("[Reset %0d] FAIL: AW FIFO not empty after reset", reset_idx))

        if (vseqr.vif.wfifo_empty !== 1'b1)
            `uvm_error(get_type_name(),
                $sformatf("[Reset %0d] FAIL: W FIFO not empty after reset", reset_idx))

        if (vseqr.vif.bfifo_empty !== 1'b1)
            `uvm_error(get_type_name(),
                $sformatf("[Reset %0d] FAIL: B FIFO not empty after reset", reset_idx))

        `uvm_info(get_type_name(),
            $sformatf("[Reset %0d] Idle state OK", reset_idx),
            UVM_MEDIUM)

    endtask

endclass : axi4_random_reset_stress_seq