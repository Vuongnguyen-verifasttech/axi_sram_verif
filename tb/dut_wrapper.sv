//==============================================================================
// File          : dut_wrapper.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : Wrapper cho DUT + Behavioral SRAM model
//
// Version       : 1.1 (Fixed modport mst -> driver)
// Date          : 29-May-2026
//==============================================================================

module dut_wrapper #(
    parameter PARA_DATA_WD    = 32,
    parameter PARA_ADDR_WD    = 32,
    parameter PARA_ID_WD      = 4,
    parameter PARA_LEN_WD     = 8,
    parameter PARA_FIFO_DEPTH = 8
) (
    input logic i_clk,
    input logic i_rst_n,
    axi4_if.driver axi_if      // ← Sửa thành modport driver
);

  // ============================================================================
  // Behavioral SRAM model (simple sparse memory)
  // ============================================================================
  logic [PARA_DATA_WD-1:0] sram_mem [bit [PARA_ADDR_WD-1:0]];

  // ============================================================================
  // Instantiate real DUT
  // ============================================================================
  m_vlsi_axi4_sram #(
    .PARA_DATA_WD    (PARA_DATA_WD),
    .PARA_ADDR_WD    (PARA_ADDR_WD),
    .PARA_ID_WD      (PARA_ID_WD),
    .PARA_LEN_WD     (PARA_LEN_WD),
    .PARA_FIFO_DEPTH (PARA_FIFO_DEPTH)
  ) u_dut (
    .i_clk     (i_clk),
    .i_rst_n   (i_rst_n),

    // AXI ports - connect trực tiếp từ interface
    .i_awaddr  (axi_if.awaddr),
    .i_awvalid (axi_if.awvalid),
    .o_awready (axi_if.awready),
    .i_awburst (axi_if.awburst),
    .i_awlen   (axi_if.awlen),
    .i_awid    (axi_if.awid),

    .i_wdata   (axi_if.wdata),
    .i_wvalid  (axi_if.wvalid),
    .o_wready  (axi_if.wready),
    .i_wlast   (axi_if.wlast),

    .o_bid     (axi_if.bid),
    .o_bresp   (axi_if.bresp),
    .o_bvalid  (axi_if.bvalid),
    .i_bready  (axi_if.bready),

    .i_araddr  (axi_if.araddr),
    .i_arvalid (axi_if.arvalid),
    .o_arready (axi_if.arready),
    .i_arburst (axi_if.arburst),
    .i_arlen   (axi_if.arlen),
    .i_arid    (axi_if.arid),

    .o_rid     (axi_if.rid),
    .o_rdata   (axi_if.rdata),
    .o_rresp   (axi_if.rresp),
    .o_rvalid  (axi_if.rvalid),
    .o_rlast   (axi_if.rlast),
    .i_rready  (axi_if.rready),

    // SRAM backend (chưa connect, để trống cho sau này)
    .o_sram_addr  (),
    .o_sram_wdata (),
    .o_sram_we    (),
    .o_sram_oe    (),
    .i_sram_rdata ()
  );

endmodule : dut_wrapper