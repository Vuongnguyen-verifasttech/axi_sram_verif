//==============================================================================
// File          : tb_top.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Testbench Top Module
//                 - Instantiate DUT + AXI4 Interface + UVM Environment
//                 - Generate clock & reset
//                 - Pass virtual interface to UVM via config_db
//                 - Start UVM test
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
import axi4_pkg::*;

module tb_top;

  // =====================================================================
  // Clock & Reset Generation
  // =====================================================================
  logic clk   = 0;
  logic rst_n = 0;

  always #5 clk = ~clk;                    // 100 MHz clock

  initial begin
    rst_n = 0;
    #50 rst_n = 1;                         // release reset after 50ns
  end

  // =====================================================================
  // AXI4 Interface
  // =====================================================================
  axi4_if #(
    .PARA_DATA_WD (32),
    .PARA_ADDR_WD (32),
    .PARA_ID_WD   (4),
    .PARA_LEN_WD  (8)
  ) axi_if (
    .i_clk   (clk),
    .i_rst_n (rst_n)
  );

  // =====================================================================
  // DUT Wrapper (chứa DUT + SRAM behavioral model)
  // =====================================================================
  dut_wrapper #(
    .PARA_DATA_WD    (32),
    .PARA_ADDR_WD    (32),
    .PARA_ID_WD      (4),
    .PARA_LEN_WD     (8),
    .PARA_FIFO_DEPTH (8)
  ) dut_wrapper_inst (
    .i_clk   (clk),
    .i_rst_n (rst_n),
    .axi_if  (axi_if)
  );

  // =====================================================================
  // UVM Environment
  // =====================================================================
  axi4_env env;

  // =====================================================================
  // Initial block - Start UVM
  // =====================================================================
  initial begin
    // Truyền virtual interface xuống UVM Environment
    uvm_config_db#(virtual axi4_if.driver)::set(null, "uvm_test_top.env.agent*", "vif", axi_if);

    // Khởi tạo UVM
    uvm_top.finish_on_completion = 1;
    run_test();                       // Chạy test (sẽ dùng +UVM_TESTNAME khi chạy sim)
  end

  // =====================================================================
  // Waveform dump (dùng cho VCS/Questa)
  // =====================================================================
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end

endmodule : tb_top