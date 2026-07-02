`timescale 1ns/1ps

// =============================================================================
// axi4_random_reset_stress_seq.sv
// AXI_05 - Random Reset Stress
//
// Goals:
//   - Reset injected randomly while write + read traffic is running
//   - Reset can hit any channel: AW, W, B, AR, R
//   - After each reset, DUT must:
//       1. Recover (awready/wready/arready back to idle, bvalid/rvalid = 0)
//       2. No deadlock (new transaction after reset must complete)
//       3. No spurious response (bvalid/rvalid must not assert while rst_n=0)
//
// Flow:
//   - traffic_thread : continuously sends random write + read
//   - reset_thread   : after random delay, injects one reset; repeats N times
//   - check_thread   : monitors for spurious bvalid/rvalid during rst_n=0
//   - After N resets : stop traffic, wait for recovery, final idle + deadlock check
//
// =============================================================================

class axi4_random_reset_stress_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_random_reset_stress_seq)

    // =========================================================================
    // Knobs — can be overridden from test
    // =========================================================================
    int unsigned num_resets        = 5;    // Number of resets to inject
    int unsigned min_delay_cycles  = 5;    // Min delay between resets (clock cycles)
    int unsigned max_delay_cycles  = 50;   // Max delay between resets (clock cycles)
    int unsigned post_reset_settle = 10;   // Cycles to wait after deassert before idle check

    // =========================================================================
    // Internal tracking
    // =========================================================================
    int unsigned reset_count;
    int unsigned spurious_bvalid_count;
    int unsigned spurious_rvalid_count;

    // Use bit flags instead of event.triggered — .triggered is only true in
    // the same timestep as ->, which expires before seq.start() returns.
    bit          traffic_stop_req;
    bit          all_resets_done;

    // Set boi traffic_thread khi no da break sach (transaction dang do da
    // hoan tat). Main body cho co nay TRUOC khi disable fork, de khong giet
    // traffic giua luc dang write -> tranh bo lai 1 AW trong FIFO cua DUT.
    bit          traffic_done;

    event        e_all_resets_done;

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

        reset_count           = 0;
        spurious_bvalid_count = 0;
        spurious_rvalid_count = 0;
        traffic_stop_req      = 0;
        all_resets_done       = 0;

        `uvm_info(get_type_name(),
            $sformatf("START Random Reset Stress: %0d resets, delay %0d..%0d cycles, settle=%0d",
                      num_resets, min_delay_cycles, max_delay_cycles, post_reset_settle),
            UVM_LOW)

        // =====================================================================
        // Fork 3 threads
        // =====================================================================
        fork

            // ------------------------------------------------------------------
            // Thread 1: TRAFFIC — send write + read until traffic_stop_req set.
            // Check the flag at the top of each loop so we never enter a new
            // transaction after the stop request arrives.
            // ------------------------------------------------------------------
            begin : traffic_thread
                forever begin
                    axi4_single_wr_seq wr_seq;
                    axi4_single_rd_seq rd_seq;

                    if (traffic_stop_req) break;

                    wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
                    wr_seq.start(vseqr.wr_seqr);

                    if (traffic_stop_req) break;

                    rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
                    rd_seq.start(vseqr.rd_seqr);
                end
                // Da break sach: transaction cuoi (neu co) da chay xong tren
                // bus, khong con write dang do -> bao cho main body.
                traffic_done = 1;
            end

            // ------------------------------------------------------------------
            // Thread 2: RESET INJECTION — inject N resets, each after a random
            //           delay so the reset hits a random channel.
            // ------------------------------------------------------------------
            begin : reset_thread
                repeat (num_resets) begin
                    int unsigned delay_cyc;
                    delay_cyc = $urandom_range(min_delay_cycles, max_delay_cycles);

                    `uvm_info(get_type_name(),
                        $sformatf("[Reset %0d/%0d] Waiting %0d cycles before inject",
                                  reset_count + 1, num_resets, delay_cyc),
                        UVM_MEDIUM)

                    repeat (delay_cyc) @(posedge vseqr.vif.i_clk);

                    reset_count++;
                    `uvm_info(get_type_name(),
                        $sformatf("[Reset %0d/%0d] INJECT reset @ %0t",
                                  reset_count, num_resets, $time),
                        UVM_LOW)

                    rst_seq = axi4_reset_seq::type_id::create("rst_seq");
                    rst_seq.start(vseqr);

                    // Settle before per-reset idle check
                    repeat (post_reset_settle) @(posedge vseqr.vif.i_clk);

                    // Only check B/R/FIFO signals — AW/AR ready cannot be
                    // reliably checked here because the traffic thread may
                    // already have issued a new AW/AR request by this point.
                    check_idle_state_during_stress(reset_count);
                end

                // Signal traffic to stop and release the main body
                traffic_stop_req = 1;
                all_resets_done  = 1;
                -> e_all_resets_done;
            end

            // ------------------------------------------------------------------
            // Thread 3: SPURIOUS CHECK — monitor every cycle; flag any
            //           bvalid/rvalid that appears while rst_n=0.
            // Uses all_resets_done bit flag (not event.triggered) so the break
            // is reliable even if the edge was many cycles ago.
            // ------------------------------------------------------------------
            begin : check_thread
                forever begin
                    @(posedge vseqr.vif.i_clk);

                    if (all_resets_done) break;

                    if (vseqr.vif.i_rst_n === 1'b0) begin

                        if (vseqr.vif.bvalid === 1'b1) begin
                            spurious_bvalid_count++;
                            `uvm_error(get_type_name(),
                                $sformatf("FAIL: BVALID=1 while rst_n=0 (count=%0d @ %0t)",
                                          spurious_bvalid_count, $time))
                        end

                        if (vseqr.vif.rvalid === 1'b1) begin
                            spurious_rvalid_count++;
                            `uvm_error(get_type_name(),
                                $sformatf("FAIL: RVALID=1 while rst_n=0 (count=%0d @ %0t)",
                                          spurious_rvalid_count, $time))
                        end

                        if (vseqr.vif.awready === 1'b1)
                            `uvm_info(get_type_name(),
                                $sformatf("NOTE: AWREADY=1 while rst_n=0 @ %0t (verify DUT spec)",
                                          $time),
                                UVM_HIGH)

                    end
                end
            end

        join_none

        // Wait for all resets to complete.
        @e_all_resets_done;

        // Cho traffic_thread break SACH (hoan tat transaction dang do) truoc
        // khi disable fork. Neu disable fork ngay bay gio, ta co the giet
        // traffic giua luc dang write -> AW da vao FIFO cua DUT nhung W chua
        // gui xong -> AW FIFO khong bao gio duoc pop -> final idle check FAIL
        // (AW FIFO not empty / AWREADY not HIGH). traffic_stop_req da duoc set,
        // nen traffic_thread se break o vong lap ke tiep.
        wait (traffic_done === 1'b1);

        // Gio chi con check_thread song -> disable fork an toan.
        disable fork;

        // Let any in-flight transaction settle before final checks
        repeat (post_reset_settle) @(posedge vseqr.vif.i_clk);

        // =====================================================================
        // FULL IDLE CHECK — traffic is now stopped, reliable to check all signals
        // =====================================================================
        check_idle_state_full();

        // =====================================================================
        // DEADLOCK CHECK — send 1 write + 1 read; tb_top watchdog catches hangs
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
                "POST-STRESS SANITY: PASS -- DUT not deadlocked after stress reset",
                UVM_LOW)
        end

        // =====================================================================
        // Summary
        // =====================================================================
        `uvm_info(get_type_name(),
            $sformatf("SUMMARY: %0d resets injected | spurious BVALID=%0d | spurious RVALID=%0d",
                      reset_count, spurious_bvalid_count, spurious_rvalid_count),
            UVM_LOW)

        if (spurious_bvalid_count == 0 && spurious_rvalid_count == 0)
            `uvm_info(get_type_name(), "PASS: Random Reset Stress PASSED", UVM_LOW)
        else
            `uvm_error(get_type_name(),
                $sformatf("FAIL: %0d spurious response(s) detected during reset",
                          spurious_bvalid_count + spurious_rvalid_count))

    endtask

    // =========================================================================
    // Diagnostic snapshot sau moi reset -- CHI LOG, khong uvm_error.
    //
    // Ham nay chay ~15 cycle SAU khi reset da nha (5 settle trong reset_seq +
    // post_reset_settle), trong khi traffic_thread chay SONG SONG da co the
    // phong write/read moi. Vi vay bvalid/rvalid/wfifo/bfifo o day co the dang
    // ban vi transaction HOP LE sau reset -> so sanh == idle se false-positive
    // (vd "RVALID not LOW after reset" du DUT hoan toan dung).
    //
    // Kiem tra spurious response DUNG THOI DIEM (trong luc i_rst_n=0) da duoc:
    //   - check_thread (sample chi khi i_rst_n===0), va
    //   - interface assertions p_bvalid/p_rvalid_low_during_reset
    // dam nhiem. Kiem tra idle THUC SU nam o check_idle_state_full() sau khi
    // traffic da dung han. Nen o day chi log de quan sat, khong fail.
    // =========================================================================
    virtual task check_idle_state_during_stress(int unsigned reset_idx);

        `uvm_info(get_type_name(),
            $sformatf("[Reset %0d] Post-reset snapshot (traffic running): bvalid=%0b rvalid=%0b wfifo_empty=%0b bfifo_empty=%0b",
                      reset_idx, vseqr.vif.bvalid, vseqr.vif.rvalid,
                      vseqr.vif.wfifo_empty, vseqr.vif.bfifo_empty),
            UVM_MEDIUM)

    endtask

    // =========================================================================
    // Full idle check — called only after traffic has fully stopped.
    // Safe to check AW/AR ready here.
    // =========================================================================
    virtual task check_idle_state_full();

        `uvm_info(get_type_name(), "FINAL IDLE CHECK (traffic stopped)...", UVM_MEDIUM)

        if (vseqr.vif.awready !== 1'b1)
            `uvm_error(get_type_name(), "FAIL: AWREADY not HIGH after stress")

        if (vseqr.vif.arready !== 1'b1)
            `uvm_error(get_type_name(), "FAIL: ARREADY not HIGH after stress")

        if (vseqr.vif.bvalid !== 1'b0)
            `uvm_error(get_type_name(), "FAIL: BVALID not LOW after stress (spurious B response)")

        if (vseqr.vif.rvalid !== 1'b0)
            `uvm_error(get_type_name(), "FAIL: RVALID not LOW after stress (spurious R response)")

        if (vseqr.vif.awfifo_empty !== 1'b1)
            `uvm_error(get_type_name(), "FAIL: AW FIFO not empty after stress")

        if (vseqr.vif.wfifo_empty !== 1'b1)
            `uvm_error(get_type_name(), "FAIL: W FIFO not empty after stress")

        if (vseqr.vif.bfifo_empty !== 1'b1)
            `uvm_error(get_type_name(), "FAIL: B FIFO not empty after stress")

        `uvm_info(get_type_name(), "FINAL IDLE CHECK: OK", UVM_MEDIUM)

    endtask

endclass : axi4_random_reset_stress_seq
