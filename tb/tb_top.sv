`timescale 1ns/1ps

// =============================================================================
// tb_top.sv
// Testbench top-level module
// Instantiate DUT, interface, SRAM model, và kick off UVM test
// =============================================================================
import uvm_pkg::*;
`include "uvm_macros.svh" // Đã bỏ dấu chấm phẩy thừa ở đây
import axi4_test_pkg::*;  // con 1 cach nua la that run_test() thanhf run_test("axi4_base_test"); nhung cach nay tienj hon
import axi4_env_pkg::*;

module tb_top;

    // =========================================================================
    // Clock generation
    // =========================================================================

    logic clk;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================================
    // Interface
    // =========================================================================

    axi4_if #(
        .ADDR_WD(32),
        .DATA_WD(32),
        .ID_WD  (4),
        .LEN_WD (8)
    ) axi_if();

    // Interface owns clock/reset
    assign axi_if.i_clk = clk;

    // =========================================================================
    // Initial reset
    // =========================================================================

    initial begin
        axi_if.i_rst_n = 1'b0;

        repeat (10)
            @(posedge clk);

        axi_if.i_rst_n = 1'b1;
    end

    // =========================================================================
    // Simple SRAM model (Behavioral - Đã sửa lỗi Race Condition)
    // =========================================================================
    localparam SRAM_DEPTH = 4096;
    logic [31:0] sram_mem [0:SRAM_DEPTH-1];
    logic [31:0] sram_rdata;
    logic [31:0] sram_addr;
    logic [31:0] sram_wdata;
    logic        sram_we;
    logic        sram_oe;

    initial begin
        foreach (sram_mem[i]) sram_mem[i] = 32'hxxxxxxxx;
    end

    // Ghi đồng bộ
    always @(posedge clk) begin
        if (sram_we)
            sram_mem[sram_addr[11:2]] <= sram_wdata;
    end

    // Đọc liên tục / tổ hợp để tránh lệch cycle khi mô phỏng cùng DUT
    //assign sram_rdata = (sram_oe) ? sram_mem[sram_addr[11:2]] : 32'h0;

    always_ff @(posedge clk) begin
    if (sram_oe)
        sram_rdata <= sram_mem[sram_addr[11:2]];
    end

    
    
    // =========================================================================
    // DUT instantiation
    // =========================================================================
    m_vlsi_axi4_sram #(
        .PARA_DATA_WD   (32),
        .PARA_ADDR_WD   (32),
        .PARA_ID_WD     (4),
        .PARA_LEN_WD    (8),
        .PARA_FIFO_DEPTH(8)
    ) u_dut (
        .i_clk (axi_if.i_clk),
        .i_rst_n (axi_if.i_rst_n),

        // AW
        .i_awaddr   (axi_if.awaddr),
        .i_awvalid  (axi_if.awvalid),
        .o_awready  (axi_if.awready),
        .i_awburst  (axi_if.awburst),
        .i_awlen    (axi_if.awlen),
        .i_awid     (axi_if.awid),

        // W
        .i_wdata    (axi_if.wdata),
        .i_wvalid   (axi_if.wvalid),
        .o_wready   (axi_if.wready),
        .i_wlast    (axi_if.wlast),

        // B
        .o_bid      (axi_if.bid),
        .o_bresp    (axi_if.bresp),
        .o_bvalid   (axi_if.bvalid),
        .i_bready   (axi_if.bready),

        // AR
        .i_araddr   (axi_if.araddr),
        .i_arvalid  (axi_if.arvalid),
        .o_arready  (axi_if.arready),
        .i_arburst  (axi_if.arburst),
        .i_arlen    (axi_if.arlen),
        .i_arid     (axi_if.arid),

        // R
        .o_rid      (axi_if.rid),
        .o_rdata    (axi_if.rdata),
        .o_rresp    (axi_if.rresp),
        .o_rvalid   (axi_if.rvalid),
        .o_rlast    (axi_if.rlast),
        .i_rready   (axi_if.rready),

        // SRAM
        .o_sram_addr  (sram_addr),
        .o_sram_wdata (sram_wdata),
        .o_sram_we    (sram_we),
        .o_sram_oe    (sram_oe),
        .i_sram_rdata (sram_rdata)
    );

    assign axi_if.awfifo_empty = u_dut.w_awfifo_empty;
    assign axi_if.arfifo_empty = u_dut.w_arfifo_empty;
    assign axi_if.wfifo_empty  = u_dut.w_wfifo_empty;
    assign axi_if.rfifo_empty  = u_dut.w_rfifo_empty;
    assign axi_if.bfifo_empty  = u_dut.w_bfifo_empty;
    assign axi_if.sram_addr = sram_addr;

    // =========================================================================
    // UVM config_db — Sửa đổi: Bỏ modport (.master/.slave) khỏi tham số DB
    // =========================================================================
  initial begin
    axi4_env_cfg env_cfg;
    env_cfg = axi4_env_cfg::type_id::create("env_cfg");
    uvm_config_db#(axi4_env_cfg)::set(null, "uvm_test_top.env", "env_cfg", env_cfg);

    uvm_config_db#(virtual axi4_if)::set(null, "uvm_test_top", "vif", axi_if);

    // Driver dùng modport master
    uvm_config_db#(virtual axi4_if.master)::set(
        null, "uvm_test_top.env.axi_agent.wr_driver", "vif", axi_if);
    uvm_config_db#(virtual axi4_if.master)::set(
        null, "uvm_test_top.env.axi_agent.rd_driver", "vif", axi_if);

    // Monitor dùng modport slave
    uvm_config_db#(virtual axi4_if.slave)::set(
        null, "uvm_test_top.env.axi_agent.wr_monitor", "vif", axi_if);
    uvm_config_db#(virtual axi4_if.slave)::set(
        null, "uvm_test_top.env.axi_agent.rd_monitor", "vif", axi_if);

    run_test();
end

    // =========================================================================
    // Timeout watchdog
    // =========================================================================
    initial begin
        #2_000_000;
        `uvm_fatal("TIMEOUT", "Simulation timeout at 2ms")
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

endmodule : tb_top