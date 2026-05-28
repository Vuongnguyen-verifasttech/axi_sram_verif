`ifndef AXI_IF_SV
`define AXI_IF_SV

`include "axi/typedef.svh"
`include "axi/assign.svh"

interface axi_if #(
  parameter int unsigned AXI_ADDR_WIDTH = 32,
  parameter int unsigned AXI_DATA_WIDTH = 64,
  parameter int unsigned AXI_ID_WIDTH   = 4,
  parameter int unsigned AXI_USER_WIDTH = 1
) (
  input logic clk_i,
  input logic rst_ni
);

  // AXI_BUS chuẩn của pulp-platform (phiên bản tương thích QuestaSim cũ)
  AXI_BUS #(
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ID_WIDTH   (AXI_ID_WIDTH),
    .AXI_USER_WIDTH (AXI_USER_WIDTH)
  ) axi ();

endinterface

`endif