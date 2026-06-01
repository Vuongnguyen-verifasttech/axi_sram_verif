//==============================================================================
// File          : axi4_if.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : AXI4 Interface Definition for Verification Environment
//                 - Parameterizable AXI4 signals (AW, W, B, AR, R channels)
//                 - Clocking blocks (cb_driver & cb_monitor) to avoid race conditions
//                 - Modports for driver and monitor
//                 - Support all signals required by the DUT (no AxSIZE, WSTRB)
//
// Version       : 1.0
// Date          : 29-May-2026
//==============================================================================

`timescale 1ns/1ps 

interface axi4_if# (
    parameter PARA_DATA_WD = 32, 
    parameter PARA_ADDR_WD = 32, 
    parameter PARA_ID_WD = 4,
    parameter PARA_LEN_WD = 8)
(
    input logic i_clk,
    input logic i_rst_n
); 

// ============================================================================
  // AXI4 Write Address Channel (AW)
  // ============================================================================
  logic [PARA_ADDR_WD-1:0] awaddr;
  logic                    awvalid;
  logic                    awready;
  logic [             1:0] awburst;
  logic [ PARA_LEN_WD-1:0] awlen;
  logic [  PARA_ID_WD-1:0] awid;

  // ============================================================================
  // AXI4 Write Data Channel (W)
  // ============================================================================
  logic [PARA_DATA_WD-1:0] wdata;
  logic                    wvalid;
  logic                    wready;
  logic                    wlast;

  // ============================================================================
  // AXI4 Write Response Channel (B)
  // ============================================================================
  logic [PARA_ID_WD-1:0] bid;
  logic [           1:0] bresp;
  logic                  bvalid;
  logic                  bready;

  // ============================================================================
  // AXI4 Read Address Channel (AR)
  // ============================================================================
  logic [PARA_ADDR_WD-1:0] araddr;
  logic                    arvalid;
  logic                    arready;
  logic [             1:0] arburst;
  logic [ PARA_LEN_WD-1:0] arlen;
  logic [  PARA_ID_WD-1:0] arid;

  // ============================================================================
  // AXI4 Read Data Channel (R)
  // ============================================================================
  logic [  PARA_ID_WD-1:0] rid;
  logic [PARA_DATA_WD-1:0] rdata;
  logic [             1:0] rresp;
  logic                    rvalid;
  logic                    rlast;
  logic                    rready;


  // ============================================================================
  // Clocking Blocks
  // ============================================================================

  clocking cb_driver @ (posedge i_clk);
    default input #1step output #0;
    output awvalid, awaddr, awlen, awburst, awid;
    output wvalid, wdata, wlast;
    output bready;
    output arvalid, araddr, arlen, arburst, arid;
    output rready;
    input awready, wready;
    input bid, bresp, bvalid;
    input arready; 
    input rid, rdata, rlast, rresp, rvalid;
  endclocking : cb_driver 

  clocking cb_monitor @(posedge i_clk);
    default input #1step;

    // Monitor samples all signals
    input awvalid, awaddr, awready, awlen, awburst, awid;
    input wvalid, wdata, wready, wlast;
    input bid, bresp, bvalid, bready;
    input arvalid, araddr, arready, arlen, arburst, arid;
    input rid, rdata, rresp, rvalid, rlast, rready;
  endclocking : cb_monitor 

  // ============================================================================
  // Modports Blocks
  // ============================================================================ 

  modport driver (clocking cb_driver, input i_rst_n);
  modport monitor (clocking cb_monitor, input i_rst_n);

endinterface :axi4_if
