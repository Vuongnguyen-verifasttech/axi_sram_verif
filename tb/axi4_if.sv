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
        input i_clk, i_rst_n
    );

    // =========================================================================
    // Modport slave — dùng trong axi4_wr_monitor và axi4_rd_monitor
    // =========================================================================
    modport slave (
        clocking slave_cb,
        input i_clk, i_rst_n
    );

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

     // ARREADY phải = 0 khi i_rst_n = 0
    property p_arready_low_during_reset;
        @(posedge i_clk)
        (!i_rst_n) |-> (!arready);
    endproperty
    assert property (p_arready_low_during_reset)
        else `uvm_error("AXI4_IF", "BUG: ARREADY=1 trong luc i_rst_n=0 — slave khong duoc accept AR request khi reset active")

    // =========================================================================
    // WRAP Address Checker
    // So sánh sram_addr thực tế DUT vs expected_addr theo AXI4 WRAP spec
    // Báo lỗi ngay tại beat vi phạm — không đợi scoreboard
    // =========================================================================
    // synthesis translate_off
    logic [ADDR_WD-1:0] chk_wrap_expected_addr;
    logic [ADDR_WD-1:0] chk_wrap_boundary;
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
        end else begin

            // Bắt AR handshake WRAP
            if (arvalid && arready && arburst == 2'b10) begin
                chk_wrap_len           <= (arlen + 1) * 4;
                chk_wrap_boundary      <= (araddr / ((arlen + 1) * 4))
                                          * ((arlen + 1) * 4);
                chk_wrap_expected_addr <= araddr;
                chk_wrap_active        <= 1;
                chk_wrap_beat          <= 0;
            end

            // Check mỗi R beat
            if (chk_wrap_active && rvalid && rready) begin
                logic [ADDR_WD-1:0] next_addr;

                if (sram_addr !== chk_wrap_expected_addr)
                    `uvm_error("AXI4_IF_WRAP",
                        $sformatf("WRAP ADDR MISMATCH beat=%0d | expected=0x%08h | dut_sram_addr=0x%08h | boundary=0x%08h",
                                  chk_wrap_beat,
                                  chk_wrap_expected_addr,
                                  sram_addr,
                                  chk_wrap_boundary))
                else
                    `uvm_info("AXI4_IF_WRAP",
                        $sformatf("WRAP ADDR OK beat=%0d | addr=0x%08h",
                                  chk_wrap_beat,
                                  chk_wrap_expected_addr),
                        UVM_HIGH)

                // Tính expected beat tiếp theo theo WRAP spec
                next_addr = chk_wrap_expected_addr + 4;
                if (next_addr >= chk_wrap_boundary + chk_wrap_len)
                    next_addr = chk_wrap_boundary;
                chk_wrap_expected_addr <= next_addr;

                if (rlast)
                    chk_wrap_active <= 0;

                chk_wrap_beat <= chk_wrap_beat + 1;
            end

        end
    end
    // synthesis translate_on

endinterface : axi4_if