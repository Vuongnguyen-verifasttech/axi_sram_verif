//==============================================================================
// File          : tb_top.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Testbench Top
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

`timescale 1ns/1ps

import uvm_pkg::*;
import axi4_pkg::*;

module tb_top;

  logic clk   = 0;
  logic rst_n = 0;

  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    #50 rst_n = 1;
  end

  axi4_if #(
    .PARA_DATA_WD (32),
    .PARA_ADDR_WD (32),
    .PARA_ID_WD   (4),
    .PARA_LEN_WD  (8)
  ) axi_if (
    .i_clk   (clk),
    .i_rst_n (rst_n)
  );

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

  // Truyền virtual interface xuống UVM
  initial begin
    uvm_config_db#(virtual axi4_if.driver)::set(null, "uvm_test_top.env.agent*", "vif", axi_if);
    run_test();
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end

endmodule : tb_top