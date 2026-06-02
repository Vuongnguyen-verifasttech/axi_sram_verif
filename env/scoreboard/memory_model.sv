`timescale 1ns/1ps

// =============================================================================
// memory_model.sv
// Golden SRAM Reference Model - Mô phỏng SRAM dùng trong Scoreboard
// =============================================================================

class memory_model extends uvm_object;

    // =====================================================================
    // Memory array (golden memory)
    // =====================================================================
    localparam MEM_SIZE = 1024 * 1024;           // 1M words (4MB) - đủ lớn cho test
    bit [31:0] mem [bit [31:0]];                 // Sparse memory (tiết kiệm RAM)

    // =====================================================================
    // UVM Automation
    // =====================================================================
    `uvm_object_utils(memory_model)

    // Constructor
    function new(string name = "memory_model");
        super.new(name);
        reset();
    endfunction

    // =====================================================================
    // Reset memory (dùng khi test reset)
    // =====================================================================
    virtual function void reset();
        mem.delete();                     // Xóa toàn bộ memory
        `uvm_info(get_type_name(), "Memory Model has been reset", UVM_LOW)
    endfunction

    // =====================================================================
    // Write one word into memory
    // =====================================================================
    virtual function void write(bit [31:0] addr, bit [31:0] data);
        mem[addr] = data;
        `uvm_info(get_type_name(), $sformatf("WRITE addr=0x%0h data=0x%0h", addr, data), UVM_HIGH)
    endfunction

    // =====================================================================
    // Read one word from memory
    // =====================================================================
    virtual function bit [31:0] read(bit [31:0] addr);
        bit [31:0] rdata;
        if (mem.exists(addr))
            rdata = mem[addr];
        else
            rdata = 32'h0;                // Default value nếu chưa write (theo RTL)

        `uvm_info(get_type_name(), $sformatf("READ  addr=0x%0h data=0x%0h", addr, rdata), UVM_HIGH)
        return rdata;
    endfunction

    // =====================================================================
    // Compare helper (scoreboard sẽ dùng)
    // =====================================================================
    virtual function bit compare(bit [31:0] addr, bit [31:0] actual_data, string context_str = "");
        bit [31:0] expected = read(addr);
        if (expected !== actual_data) begin
            `uvm_error(get_type_name(), 
                $sformatf("DATA MISMATCH %s | addr=0x%0h | expected=0x%0h | actual=0x%0h", 
                          context_str, addr, expected, actual_data))
            return 0;
        end
        return 1;
    endfunction

    // Print memory status (debug)
    virtual function string convert2string();
        return $sformatf("Memory Model: %0d locations written", mem.size());
    endfunction

endclass : memory_model