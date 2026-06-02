`timescale 1ns/1ps

interface axi4_if #(
    parameter PARA_ADDR_WD = 32,
    parameter PARA_DATA_WD = 32,
    parameter PARA_ID_WD   = 4,
    parameter PARA_LEN_WD  = 8
) (
    input logic i_clk,
    input logic i_rst_n
);

    // ====================== Write Address Channel ======================
    logic [PARA_ADDR_WD-1:0] awaddr;
    logic [PARA_ID_WD-1:0]   awid;
    logic [PARA_LEN_WD-1:0]  awlen;
    logic [1:0]              awburst;
    logic                    awvalid;
    logic                    awready;

    // ====================== Write Data Channel ======================
    logic [PARA_DATA_WD-1:0] wdata;
    logic                    wlast;
    logic                    wvalid;
    logic                    wready;

    // ====================== Write Response Channel ======================
    logic [PARA_ID_WD-1:0] bid;
    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;

    // ====================== Read Address Channel ======================
    logic [PARA_ADDR_WD-1:0] araddr;
    logic [PARA_ID_WD-1:0]   arid;
    logic [PARA_LEN_WD-1:0]  arlen;
    logic [1:0]              arburst;
    logic                    arvalid;
    logic                    arready;

    // ====================== Read Data Channel ======================
    logic [PARA_ID_WD-1:0]   rid;
    logic [PARA_DATA_WD-1:0] rdata;
    logic [1:0]              rresp;
    logic                    rlast;
    logic                    rvalid;
    logic                    rready;

    // Modport cho Master (VIP sẽ drive)
    modport master (
        input  i_clk, i_rst_n,
        output awaddr, awid, awlen, awburst, awvalid,
        input  awready,
        output wdata, wlast, wvalid,
        input  wready,
        input  bid, bresp, bvalid,
        output bready,
        output araddr, arid, arlen, arburst, arvalid,
        input  arready,
        input  rid, rdata, rresp, rlast, rvalid,
        output rready
    );

    // Modport cho Slave (DUT)
    modport slave (
        input  i_clk, i_rst_n,
        input  awaddr, awid, awlen, awburst, awvalid,
        output awready,
        input  wdata, wlast, wvalid,
        output wready,
        output bid, bresp, bvalid,
        input  bready,
        input  araddr, arid, arlen, arburst, arvalid,
        output arready,
        output rid, rdata, rresp, rlast, rvalid,
        input  rready
    );

endinterface : axi4_if