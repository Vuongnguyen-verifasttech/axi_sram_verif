`timescale 1ns/1ps

// =============================================================================
// axi4_scoreboard.sv
// Scoreboard so sánh transaction thực tế với golden memory model
// =============================================================================

class axi4_scoreboard extends uvm_scoreboard;

    // =====================================================================
    // Analysis Export (kết nối từ agent monitor)
    // =====================================================================
    uvm_analysis_imp #(axi4_transaction, axi4_scoreboard) analysis_export;

    // =====================================================================
    // Golden Model
    // =====================================================================
    memory_model mem_model;

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_component_utils(axi4_scoreboard)

    // Constructor
    function new(string name = "axi4_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =====================================================================
    // Build Phase
    // =====================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
        mem_model = memory_model::type_id::create("mem_model", this);
    endfunction

    // =====================================================================
    // Connect Phase (sẽ connect từ env)
    // =====================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Kết nối sẽ được thực hiện trong axi4_env.sv
    endfunction

    // =====================================================================
    // Write method - Nhận transaction từ monitor
    // =====================================================================
    virtual function void write(axi4_transaction tr);
        if (tr == null) begin
            `uvm_error(get_type_name(), "Received null transaction")
            return;
        end

        `uvm_info(get_type_name(), $sformatf("Received transaction: %s", tr.convert2string()), UVM_MEDIUM)

        if (tr.is_write) begin
            // WRITE: Update golden memory
            foreach (tr.data[i]) begin
                bit [31:0] addr = tr.awaddr + (i * 4);   // 32-bit word increment
                mem_model.write(addr, tr.data[i]);
            end
        end else begin
            // READ: Compare with golden memory
            foreach (tr.data[i]) begin
                bit [31:0] addr = tr.araddr + (i * 4);
                if (!mem_model.compare(addr, tr.data[i], "READ")) begin
                    `uvm_error(get_type_name(), $sformatf("READ mismatch at addr=0x%0h", addr))
                end
            end
        end

        // Check response (always OKAY for this DUT)
        if (tr.resp != 2'b00) begin
            `uvm_error(get_type_name(), $sformatf("Unexpected response 0x%0h", tr.resp))
        end
    endfunction

    // =====================================================================
    // Report Phase (summary)
    // =====================================================================
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Scoreboard finished. Memory status: %s", mem_model.convert2string()), UVM_LOW)
    endfunction

endclass : axi4_scoreboard