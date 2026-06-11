`timescale 1ns/1ps

// =============================================================================
// axi4_agent_pkg.sv
// Package gom toàn bộ AXI4 Master Agent (đã hoàn chỉnh)
// =============================================================================

package axi4_agent_pkg;

    // Import UVM base
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // =====================================================================
    // Include tất cả file của agent (THEO THỨ TỰ PHỤ THUỘC)
    // =====================================================================

    // 1. Transaction class
    `include "axi4_rd_seq_item.sv"

    `include "axi4_wr_seq_item.sv"

    // 2. Configuration class
    `include "axi4_agent_cfg.sv"

    // 3. Driver
    `include "axi4_rd_driver.sv"

    `include "axi4_wr_driver.sv"

    // 4. Monitor
    `include "axi4_rd_monitor.sv"

    `include "axi4_wr_monitor.sv"

    // 5. Sequencer
    //`include "axi4_sequencer.sv"

    // 6. Agent top-level
    `include "axi4_agent.sv"

    // =====================================================================
    // (Nếu sau này thêm class mới vào agent thì include tiếp ở đây)
    // =====================================================================

endpackage : axi4_agent_pkg