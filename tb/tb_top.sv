`timescale 1ns/1ps
`include "axi/typedef.svh"
`include "axi/assign.svh"

module tb_top;

  // Timeunit & Timeprecision (fix lỗi TSCALE)
  timeunit 1ns;
  timeprecision 1ps;

  // ====================== Parameters ======================
  localparam int unsigned AXI_ADDR_WIDTH = 32;
  localparam int unsigned AXI_DATA_WIDTH = 64;
  localparam int unsigned AXI_ID_WIDTH   = 4;
  localparam int unsigned AXI_USER_WIDTH = 1;

  // ====================== Signals ======================
  logic clk;
  logic rst_n;

  // ====================== Clock & Reset ======================
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    repeat(10) @(posedge clk);
    rst_n = 1;
  end

  // ====================== AXI Interface ======================
  axi_if #(
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ID_WIDTH   (AXI_ID_WIDTH),
    .AXI_USER_WIDTH (AXI_USER_WIDTH)
  ) axi_if_inst (
    .clk_i (clk),
    .rst_ni(rst_n)
  );

  // ====================== Monitor signals (sửa type đúng) ======================
  logic                      mon_w_valid;
  logic [AXI_ADDR_WIDTH-1:0] mon_w_addr;
  logic [AXI_DATA_WIDTH-1:0] mon_w_data;
  logic [AXI_ID_WIDTH-1:0]   mon_w_id;
  logic [AXI_USER_WIDTH-1:0] mon_w_user;
  axi_pkg::len_t             mon_w_beat_count;     // Sửa đúng type
  logic                      mon_w_last;

  logic                      mon_r_valid;
  logic [AXI_ADDR_WIDTH-1:0] mon_r_addr;
  logic [AXI_DATA_WIDTH-1:0] mon_r_data;
  logic [AXI_ID_WIDTH-1:0]   mon_r_id;
  logic [AXI_USER_WIDTH-1:0] mon_r_user;
  axi_pkg::len_t             mon_r_beat_count;     // Sửa đúng type
  logic                      mon_r_last;

  // ====================== DUT ======================
  axi_sim_mem_intf #(
    .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH     (AXI_DATA_WIDTH),
    .AXI_ID_WIDTH       (AXI_ID_WIDTH),
    .AXI_USER_WIDTH     (AXI_USER_WIDTH),
    .WARN_UNINITIALIZED (1'b1),
    .UNINITIALIZED_DATA ("random")
  ) i_dut (
    .clk_i              (clk),
    .rst_ni             (rst_n),
    .axi_slv            (axi_if_inst.axi),

    .mon_w_valid_o      (mon_w_valid),
    .mon_w_addr_o       (mon_w_addr),
    .mon_w_data_o       (mon_w_data),
    .mon_w_id_o         (mon_w_id),
    .mon_w_user_o       (mon_w_user),
    .mon_w_beat_count_o (mon_w_beat_count),
    .mon_w_last_o       (mon_w_last),

    .mon_r_valid_o      (mon_r_valid),
    .mon_r_addr_o       (mon_r_addr),
    .mon_r_data_o       (mon_r_data),
    .mon_r_id_o         (mon_r_id),
    .mon_r_user_o       (mon_r_user),
    .mon_r_beat_count_o (mon_r_beat_count),
    .mon_r_last_o       (mon_r_last)
  );

  // ====================== Test ======================
   // ====================== Basic Functionality Test ======================
  initial begin
    automatic logic [63:0] wdata = 64'hDEADBEEF_CAFEBABE;
    automatic logic [63:0] rdata;

    $display("tb_top started successfully!");

    wait (rst_n == 1);
    repeat(5) @(posedge clk);

    $display("=== Starting Basic Write/Read Test ===");

    // === Write transaction ===
    axi_if_inst.axi.aw_valid = 1;
    axi_if_inst.axi.aw.addr  = 32'h0000_1000;
    axi_if_inst.axi.aw.id    = 4'hA;
    axi_if_inst.axi.aw.len   = 8'h00;     // 1 beat
    axi_if_inst.axi.aw.size  = 3'b011;    // 8 bytes
    axi_if_inst.axi.aw.burst = 2'b01;     // INCR

    @(posedge clk);
    axi_if_inst.axi.aw_valid = 0;

    // Write data
    axi_if_inst.axi.w_valid = 1;
    axi_if_inst.axi.w.data  = wdata;
    axi_if_inst.axi.w.strb  = 8'hFF;
    axi_if_inst.axi.w.last  = 1;

    @(posedge clk);
    axi_if_inst.axi.w_valid = 0;

    // Wait for B response
    wait (axi_if_inst.axi.b_valid);
    $display("Write completed with BRESP = 0x%0h", axi_if_inst.axi.b.resp);
    axi_if_inst.axi.b_ready = 1;
    @(posedge clk);
    axi_if_inst.axi.b_ready = 0;

    // === Read transaction ===
    axi_if_inst.axi.ar_valid = 1;
    axi_if_inst.axi.ar.addr  = 32'h0000_1000;
    axi_if_inst.axi.ar.id    = 4'hA;
    axi_if_inst.axi.ar.len   = 8'h00;
    axi_if_inst.axi.ar.size  = 3'b011;
    axi_if_inst.axi.ar.burst = 2'b01;

    @(posedge clk);
    axi_if_inst.axi.ar_valid = 0;

    wait (axi_if_inst.axi.r_valid);
    rdata = axi_if_inst.axi.r.data;
    $display("Read data = 0x%016h", rdata);
    axi_if_inst.axi.r_ready = 1;
    @(posedge clk);
    axi_if_inst.axi.r_ready = 0;

    if (rdata == wdata)
      $display("✅ TEST PASSED: Write and Read data matched!");
    else
      $display("❌ TEST FAILED: Data mismatch!");

    repeat(50) @(posedge clk);
    $display("Simulation finished successfully!");
    $finish;
  end

endmodule