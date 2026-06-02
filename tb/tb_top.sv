`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// SỬA LỖI: Import các package chứa định nghĩa môi trường và testcase
// =============================================================================
import axi4_env_pkg::*;
import axi4_test_pkg::*;

// =============================================================================
// tb_top.sv
// Top-level Testbench - Tích hợp full UVM Environment
// =============================================================================

module tb_top;

    // =====================================================================
    // Parameters (phải khớp với DUT)
    // =====================================================================
    localparam PARA_ADDR_WD = 32;
    localparam PARA_DATA_WD = 32;
    localparam PARA_ID_WD   = 4;
    localparam PARA_LEN_WD  = 8;

    // =====================================================================
    // Clock & Reset
    // =====================================================================
    logic clk;
    logic rst_n;

    clk_rst_gen #(.CLK_PERIOD(10)) u_clk_rst (
        .clk   (clk),
        .rst_n (rst_n)
    );

    // =====================================================================
    // AXI4 Interface
    // =====================================================================
    axi4_if #(
        .PARA_ADDR_WD (PARA_ADDR_WD),
        .PARA_DATA_WD (PARA_DATA_WD),
        .PARA_ID_WD   (PARA_ID_WD),
        .PARA_LEN_WD  (PARA_LEN_WD)
    ) axi_if (.i_clk(clk), .i_rst_n(rst_n));

    // =====================================================================
    // DUT Instantiation
    // =====================================================================
    m_vlsi_axi4_sram #(
        .PARA_DATA_WD    (PARA_DATA_WD),
        .PARA_ADDR_WD    (PARA_ADDR_WD),
        .PARA_ID_WD      (PARA_ID_WD),
        .PARA_LEN_WD     (PARA_LEN_WD),
        .PARA_FIFO_DEPTH (8)
    ) u_dut (
        .i_clk      (clk),
        .i_rst_n    (rst_n),

        // AW channel
        .i_awaddr   (axi_if.awaddr),
        .i_awvalid  (axi_if.awvalid),
        .o_awready  (axi_if.awready),
        .i_awburst  (axi_if.awburst),
        .i_awlen    (axi_if.awlen),
        .i_awid     (axi_if.awid),

        // W channel
        .i_wdata    (axi_if.wdata),
        .i_wvalid   (axi_if.wvalid),
        .o_wready   (axi_if.wready),
        .i_wlast    (axi_if.wlast),

        // B channel
        .o_bid      (axi_if.bid),
        .o_bresp    (axi_if.bresp),
        .o_bvalid   (axi_if.bvalid),
        .i_bready   (axi_if.bready),

        // AR channel
        .i_araddr   (axi_if.araddr),
        .i_arvalid  (axi_if.arvalid),
        .o_arready  (axi_if.arready),
        .i_arburst  (axi_if.arburst),
        .i_arlen    (axi_if.arlen),
        .i_arid     (axi_if.arid),

        // R channel
        .o_rid      (axi_if.rid),
        .o_rdata    (axi_if.rdata),
        .o_rresp    (axi_if.rresp),
        .o_rvalid   (axi_if.rvalid),
        .o_rlast    (axi_if.rlast),
        .i_rready   (axi_if.rready),

        // SRAM interface (tie-off tạm thời)
        .o_sram_addr  (),
        .o_sram_wdata (),
        .o_sram_we    (),
        .o_sram_oe    (),
        .i_sram_rdata (32'h0)
    );

    // =====================================================================
    // UVM Initial Block - Bản sửa lỗi chuẩn hóa uvm_config_db
    // =====================================================================
    initial begin
        // 1. Khai báo biến lên đầu block (Tránh lỗi biên dịch cũ)
        axi4_env_cfg env_cfg; 

        $display("=========================================");
        $display("AXI4 SRAM UVM Testbench STARTED at %0t", $time);
        $display("=========================================");

        // 2. Khởi tạo env_cfg thông qua factory
        env_cfg = axi4_env_cfg::type_id::create("env_cfg");
        
        // 3. FIX CHÍNH: Pass virtual interface với đúng modport (.master) và đúng path (.*)
        uvm_config_db#(virtual axi4_if.master)::set(null, "uvm_test_top.env.axi_agent.*", "vif", axi_if);

        // 4. Set env config vào config_db
        uvm_config_db#(axi4_env_cfg)::set(null, "uvm_test_top*", "env_cfg", env_cfg);

        // 5. Chạy UVM test
        run_test();
    end
    // =====================================================================
    // Dump Waveform Block - Đã chuẩn hóa cấu trúc
    // =====================================================================
    initial begin
        $dumpfile("axi4_sram_tb.vcd");
        $dumpvars(0, tb_top);
    end
endmodule : tb_top