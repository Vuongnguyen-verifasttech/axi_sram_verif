`timescale 1ns/1ps

// =============================================================================
// axi4_env_pkg.sv
// Package đã được sửa lại thứ tự include chính xác
// =============================================================================

package axi4_env_pkg;
    // Import UVM base
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import package của agent
    import axi4_agent_pkg::*;

    // =====================================================================
    // Include các file của env (Theo thứ tự phụ thuộc chuẩn)
    // =====================================================================

    // 1. Golden Model (Độc lập, cần cho Scoreboard)
    `include "scoreboard/memory_model.sv"

    // 2. Environment Configuration (Cần cho Env)
    `include "axi4_env_cfg.sv"

    // 3. Scoreboard (Cần memory_model, và cần đứng trước Env)
    `include "scoreboard/axi4_scoreboard.sv"

    // 4. Main Environment (Sử dụng cả Config và Scoreboard)
    `include "axi4_env.sv"

    // =====================================================================
    // (Coverage sẽ include sau khi viết xong)
    // `include "coverage/axi4_coverage.sv"
    // =====================================================================

endpackage : axi4_env_pkg