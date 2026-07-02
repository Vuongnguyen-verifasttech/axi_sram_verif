`timescale 1ns/1ps

// =============================================================================
// axi4_if.sv
// AXI4 Interface definition
// Gồm clocking blocks để đảm bảo sample/drive đúng clock domain
// Modports: master (driver dùng), slave (monitor dùng)
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh"
interface axi4_if #(
    parameter ADDR_WD = 32,
    parameter DATA_WD = 32,
    parameter ID_WD   = 4,
    parameter LEN_WD  = 8
) (
   // input logic i_clk,
   // input logic i_rst_n
);
    //De cho interface so huu reset 
    logic i_clk;
    logic i_rst_n;

    // =========================================================================
    // AW channel
    // =========================================================================
    logic [ADDR_WD-1:0] awaddr;
    logic               awvalid;
    logic               awready;
    logic [1:0]         awburst;
    logic [LEN_WD-1:0]  awlen;
    logic [ID_WD-1:0]   awid;

    // =========================================================================
    // W channel
    // =========================================================================
    logic [DATA_WD-1:0] wdata;
    logic               wvalid;
    logic               wready;
    logic               wlast;

    // =========================================================================
    // B channel
    // =========================================================================
    logic [ID_WD-1:0]   bid;
    logic [1:0]         bresp;
    logic               bvalid;
    logic               bready;

    // =========================================================================
    // AR channel
    // =========================================================================
    logic [ADDR_WD-1:0] araddr;
    logic               arvalid;
    logic               arready;
    logic [1:0]         arburst;
    logic [LEN_WD-1:0]  arlen;
    logic [ID_WD-1:0]   arid;

    // =========================================================================
    // R channel
    // =========================================================================
    logic [ID_WD-1:0]   rid;
    logic [DATA_WD-1:0] rdata;
    logic [1:0]         rresp;
    logic               rvalid;
    logic               rlast;
    logic               rready;

    // DUT internal — wire từ tb_top: assign axi_if.sram_addr = sram_addr
    logic [ADDR_WD-1:0] sram_addr;

    //==============================================================
    // FIFO
    //==============================================================

    logic awfifo_empty;
    logic arfifo_empty;
    logic wfifo_empty;
    logic rfifo_empty;
    logic bfifo_empty;

    // =========================================================================
    // Master clocking block (driver perspective)
    // Drive: output signals, sample: input signals
    // #1 setup skew để tránh race với posedge
    // =========================================================================
    clocking master_cb @(posedge i_clk);
        default input #1 output #1;
        // AW
        output awaddr, awvalid, awburst, awlen, awid;
        input  awready;
        // W
        output wdata, wvalid, wlast;
        input  wready;
        // B
        output bready;
        input  bid, bresp, bvalid;
        // AR
        output araddr, arvalid, arburst, arlen, arid;
        input  arready;
        // R
        output rready;
        input  rid, rdata, rresp, rvalid, rlast;
    endclocking

    // =========================================================================
    // Slave clocking block (monitor perspective)
    // Monitor chỉ sample — không drive
    // =========================================================================
    clocking slave_cb @(posedge i_clk);
        default input #1;
        // AW
        input awaddr, awvalid, awready, awburst, awlen, awid;
        // W
        input wdata, wvalid, wready, wlast;
        // B
        input bid, bresp, bvalid, bready;
        // AR
        input araddr, arvalid, arready, arburst, arlen, arid;
        // R
        input rid, rdata, rresp, rvalid, rlast, rready;
    endclocking

    // =========================================================================
    // Modport master — dùng trong axi4_wr_driver và axi4_rd_driver
    // =========================================================================
    modport master (
        clocking master_cb,
        input i_clk, i_rst_n,
        // Direct net access — CHỈ dùng để force-reset signals về 0 ngay lập tức
        // khi i_rst_n=0, bypass clocking block skew (#1) để tránh data rác
        // bị đẩy vào DUT trong cycle reset đầu tiên.
        // KHÔNG dùng các signal này cho transaction bình thường — luôn dùng master_cb.
        output awvalid, awaddr, awburst, awlen, awid,
        output wvalid, wdata, wlast,
        output bready,
        output arvalid, araddr, arburst, arlen, arid,
        output rready
    );

    // =========================================================================
    // Modport slave — dùng trong axi4_wr_monitor và axi4_rd_monitor
    // =========================================================================
    modport slave (
        clocking slave_cb,
        input i_clk, i_rst_n
    );
/*
    // =========================================================================
    // Assertions — AXI4 protocol checks
    // =========================================================================

    // AWVALID không được deassert khi đang chờ AWREADY (stability)
    property p_awvalid_stable;
        @(posedge i_clk) disable iff (!i_rst_n)
        (awvalid && !awready) |=> awvalid;
    endproperty
    assert property (p_awvalid_stable)
        else `uvm_error("AXI4_IF", "AWVALID deasserted before AWREADY")

    // WVALID không được deassert khi đang chờ WREADY
    property p_wvalid_stable;
        @(posedge i_clk) disable iff (!i_rst_n)
        (wvalid && !wready) |=> wvalid;
    endproperty
    assert property (p_wvalid_stable)
        else `uvm_error("AXI4_IF", "WVALID deasserted before WREADY")

    // ARVALID stability
    property p_arvalid_stable;
        @(posedge i_clk) disable iff (!i_rst_n)
        (arvalid && !arready) |=> arvalid;
    endproperty
    assert property (p_arvalid_stable)
        else `uvm_error("AXI4_IF", "ARVALID deasserted before ARREADY")

    // WLAST phải match awlen (beat count)
    // (checked in scoreboard — không thể check di interface vì không biết awlen ở đây)

 */

    // =========================================================================
    // Reset behaviour checks -- theo AMBA AXI spec, khi i_rst_n=0:
    //   - Master PHAI drive AWVALID/WVALID/ARVALID = LOW
    //   - Slave  PHAI drive BVALID/RVALID          = LOW
    //   - READY (AWREADY/WREADY/ARREADY) co the la BAT KY gia tri -> KHONG check.
    //
    // Vay AWREADY=1 trong luc reset KHONG phai bug. Van de "AWVALID=1 khi reset"
    // la vi pham spec ve phia MASTER (driver testbench), va cac assertion duoi
    // day bat dung loi do -- day la self-check cho driver, khong phai giao RTL.
    // =========================================================================

    // --- Master VALID phai LOW khi reset (loi driver testbench) ---
    property p_awvalid_low_during_reset;
        @(posedge i_clk) (!i_rst_n) |-> (!awvalid);
    endproperty
    assert property (p_awvalid_low_during_reset)
        else `uvm_error("AXI4_IF", "SPEC VIOLATION: AWVALID=1 trong luc i_rst_n=0 : master phai drive AWVALID LOW khi reset")

    property p_wvalid_low_during_reset;
        @(posedge i_clk) (!i_rst_n) |-> (!wvalid);
    endproperty
    assert property (p_wvalid_low_during_reset)
        else `uvm_error("AXI4_IF", "SPEC VIOLATION: WVALID=1 trong luc i_rst_n=0 : master phai drive WVALID LOW khi reset")

    property p_arvalid_low_during_reset;
        @(posedge i_clk) (!i_rst_n) |-> (!arvalid);
    endproperty
    assert property (p_arvalid_low_during_reset)
        else `uvm_error("AXI4_IF", "SPEC VIOLATION: ARVALID=1 trong luc i_rst_n=0 : master phai drive ARVALID LOW khi reset")

    // --- Slave VALID phai LOW khi reset (loi RTL DUT) ---
    property p_bvalid_low_during_reset;
        @(posedge i_clk) (!i_rst_n) |-> (!bvalid);
    endproperty
    assert property (p_bvalid_low_during_reset)
        else `uvm_error("AXI4_IF", "SPEC VIOLATION: BVALID=1 trong luc i_rst_n=0 : slave phai drive BVALID LOW khi reset")

    property p_rvalid_low_during_reset;
        @(posedge i_clk) (!i_rst_n) |-> (!rvalid);
    endproperty
    assert property (p_rvalid_low_during_reset)
        else `uvm_error("AXI4_IF", "SPEC VIOLATION: RVALID=1 trong luc i_rst_n=0 : slave phai drive RVALID LOW khi reset")

    // =========================================================================
    // WRAP Address Checker
    // =========================================================================
    // synthesis translate_off
    logic [ADDR_WD-1:0] chk_wrap_expected_addr;
    logic [ADDR_WD-1:0] chk_wrap_boundary;
    logic [ADDR_WD-1:0] chk_wrap_next_addr;
    logic [31:0]        chk_wrap_len;
    logic               chk_wrap_active;
    int                 chk_wrap_beat;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            chk_wrap_active        <= 0;
            chk_wrap_beat          <= 0;
            chk_wrap_expected_addr <= 0;
            chk_wrap_boundary      <= 0;
            chk_wrap_len           <= 0;
            chk_wrap_next_addr     <= 0;
        end else begin

            if (arvalid && arready && arburst == 2'b10) begin
                chk_wrap_len           <= (arlen + 1) * 4;
                chk_wrap_boundary      <= (araddr / ((arlen + 1) * 4))
                                          * ((arlen + 1) * 4);
                chk_wrap_expected_addr <= araddr;
                chk_wrap_active        <= 1;
                chk_wrap_beat          <= 0;
            end

            if (chk_wrap_active && rvalid && rready) begin

                if (sram_addr !== chk_wrap_expected_addr)
                    `uvm_error("AXI4_IF_WRAP",
                        $sformatf("WRAP ADDR MISMATCH beat=%0d | expected=0x%08h | dut_sram_addr=0x%08h | boundary=0x%08h",
                                  chk_wrap_beat, chk_wrap_expected_addr,
                                  sram_addr, chk_wrap_boundary))
                else
                    `uvm_info("AXI4_IF_WRAP",
                        $sformatf("WRAP ADDR OK beat=%0d | addr=0x%08h",
                                  chk_wrap_beat, chk_wrap_expected_addr),
                        UVM_HIGH)

                chk_wrap_next_addr = chk_wrap_expected_addr + 4;
                if (chk_wrap_next_addr >= chk_wrap_boundary + chk_wrap_len)
                    chk_wrap_next_addr = chk_wrap_boundary;
                chk_wrap_expected_addr <= chk_wrap_next_addr;

                if (rlast) chk_wrap_active <= 0;
                chk_wrap_beat <= chk_wrap_beat + 1;
            end

        end
    end
    // synthesis translate_on

    // =========================================================================
    // RLAST Checker  (RTL bug hand-off)
    //
    // Yeu cau AXI: moi read burst phai co RLAST asserted DUNG o beat thu
    // (ARLEN+1), khong som khong tre.
    //
    // Bug quan sat (giao RTL): sau khi mot reset chen vao GIUA mot read dang
    // chay, read ke tiep tra ve du (ARLEN+1) beat nhung RLAST khong bao gio
    // len -> "RLAST_MISSING". Nghi ngo o read datapath m_vlsi_sram_misc.sv
    // (pipeline reg_rd_pending / reg_rd_last_d) va/hoac sinh o_last cua
    // m_vlsi_axfsm.sv khong phuc hoi dung sau reset giua burst.
    //
    // Checker nay DOC LAP voi driver (driver co check rieng trong
    // drive_r_channel), dat o interface de lam artifact giao RTL. Dung queue
    // de ho tro AR duoc chap nhan truoc khi R cua read truoc drain xong
    // (pipelined). Reset xoa sach state -> khong desync qua reset.
    // =========================================================================
    // synthesis translate_off
    int chk_rd_expected_q[$];   // (ARLEN+1) cua tung read con outstanding
    int chk_rd_beat;            // so beat da nhan cua read o dau hang doi

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            chk_rd_expected_q.delete();
            chk_rd_beat = 0;
        end else begin

            // AR handshake -> enqueue so beat mong doi cua read nay.
            if (arvalid && arready)
                chk_rd_expected_q.push_back(int'(arlen) + 1);

            // R beat transfer.
            if (rvalid && rready) begin
                if (chk_rd_expected_q.size() == 0) begin
                    `uvm_error("AXI4_IF_RLAST",
                        "RTL BUG: R beat (RVALID&&RREADY) nhung khong co AR outstanding")
                end
                else begin
                    chk_rd_beat = chk_rd_beat + 1;

                    if (rlast) begin
                        if (chk_rd_beat != chk_rd_expected_q[0])
                            `uvm_error("AXI4_IF_RLAST",
                                $sformatf("RTL BUG: RLAST o beat %0d nhung mong doi %0d (=ARLEN+1)",
                                          chk_rd_beat, chk_rd_expected_q[0]))
                        void'(chk_rd_expected_q.pop_front());
                        chk_rd_beat = 0;
                    end
                    else if (chk_rd_beat == chk_rd_expected_q[0]) begin
                        `uvm_error("AXI4_IF_RLAST",
                            $sformatf("RTL BUG: RLAST_MISSING -- nhan du %0d beat (=ARLEN+1) nhung RLAST khong asserted",
                                      chk_rd_beat))
                        // Phuc hoi de khong lech cac read sau.
                        void'(chk_rd_expected_q.pop_front());
                        chk_rd_beat = 0;
                    end
                end
            end

        end
    end
    // synthesis translate_on

endinterface : axi4_if