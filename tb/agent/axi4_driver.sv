//==============================================================================
// File          : axi4_if.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : AXI4 Interface with complete modport 'driver'
//                 - Fixed modport to include ALL signals needed by DUT
//
// Version       : 1.3 (Fixed modport driver)
// Date          : 29-May-2026
//==============================================================================

`timescale 1ns/1ps 

interface axi4_if #(
    parameter PARA_DATA_WD = 32, 
    parameter PARA_ADDR_WD = 32, 
    parameter PARA_ID_WD   = 4,
    parameter PARA_LEN_WD  = 8
) (
    input logic i_clk,
    input logic i_rst_n
); 

  // ============================================================================
  // AXI4 Signals
  // ============================================================================
  logic [PARA_ADDR_WD-1:0] awaddr;
  logic                    awvalid;
  logic                    awready;
  logic [             1:0] awburst;
  logic [ PARA_LEN_WD-1:0] awlen;
  logic [  PARA_ID_WD-1:0] awid;

  logic [PARA_DATA_WD-1:0] wdata;
  logic                    wvalid;
  logic                    wready;
  logic                    wlast;

  logic [PARA_ID_WD-1:0] bid;
  logic [           1:0] bresp;
  logic                  bvalid;
  logic                  bready;

  logic [PARA_ADDR_WD-1:0] araddr;
  logic                    arvalid;
  logic                    arready;
  logic [             1:0] arburst;
  logic [ PARA_LEN_WD-1:0] arlen;
  logic [  PARA_ID_WD-1:0] arid;

  logic [  PARA_ID_WD-1:0] rid;
  logic [PARA_DATA_WD-1:0] rdata;
  logic [             1:0] rresp;
  logic                    rvalid;
  logic                    rlast;
  logic                    rready;

  // ============================================================================
  // Clocking Blocks
  // ============================================================================
  clocking cb_driver @(posedge i_clk);
    default input #1step output #0;

    // Master (testbench) outputs
    output awvalid, awaddr, awlen, awburst, awid;
    output wvalid, wdata, wlast;
    output arvalid, araddr, arlen, arburst, arid;
    output bready, rready;

    // Master inputs
    input  awready, wready;
    input  bid, bresp, bvalid;
    input  arready;
    input  rid, rdata, rresp, rvalid, rlast;
  endclocking : cb_driver 

  clocking cb_monitor @(posedge i_clk);
    default input #1step;
    input awvalid, awaddr, awready, awlen, awburst, awid;
    input wvalid, wdata, wready, wlast;
    input bid, bresp, bvalid, bready;
    input arvalid, araddr, arready, arlen, arburst, arid;
    input rid, rdata, rresp, rvalid, rlast, rready;
  endclocking : cb_monitor 

  // ============================================================================
  // Modports
  // ============================================================================
  modport driver  (clocking cb_driver,  input i_rst_n);
  modport monitor (clocking cb_monitor, input i_rst_n);

endinterface : axi4_if