`timescale 1ns/1ps

// =============================================================================
// axi4_env_pkg.sv
// Package cho toàn bộ AXI4 SRAM UVM Environment (đã include scoreboard)
// =============================================================================

package axi4_env_pkg;

    // Import UVM base
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // =====================================================================
    // Import package của agent
    // =====================================================================
    import axi4_agent_pkg::*;

    // =====================================================================
    // Include các file của env (theo thứ tự phụ thuộc)
    // =====================================================================

    // 1. Environment Configuration
    `include "axi4_env_cfg.sv"

    // 2. Main Environment
    `include "axi4_env.sv"

    // 3. Scoreboard
    `include "scoreboard/axi4_scoreboard.sv"

    // =====================================================================
    // (Coverage sẽ include sau khi viết xong)
    // `include "coverage/axi4_coverage.sv"
    // =====================================================================

endpackage : axi4_env_pkg