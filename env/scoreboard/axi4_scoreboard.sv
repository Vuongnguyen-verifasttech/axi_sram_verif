`timescale 1ns/1ps

// =============================================================================
// axi4_scoreboard.sv
//
// Scoreboard cho m_vlsi_axi4_sram
//
// Chức năng:
//   - Shadow memory model
//   - Check write response
//   - Check read response
//   - Check ID propagation
//   - Compare read data với memory model
//
// Lưu ý:
//   - Match DUT implementation hiện tại
//   - Không implement AXI4 WRAP chuẩn
//   - BRESP/RRESP luôn kỳ vọng = OKAY (2'b00)
// =============================================================================

class axi4_scoreboard extends uvm_scoreboard;

    // =========================================================================
    // Analysis imports
    // =========================================================================
    `uvm_analysis_imp_decl(_wr)
    `uvm_analysis_imp_decl(_rd)

    uvm_analysis_imp_wr #(axi4_wr_seq_item, axi4_scoreboard) ae_wr;
    uvm_analysis_imp_rd #(axi4_rd_seq_item, axi4_scoreboard) ae_rd;

    // =========================================================================
    // Shadow memory
    // word address = byte_addr >> 2
    // =========================================================================
    logic [31:0] shadow_mem [logic [31:0]];

    // =========================================================================
    // Statistics
    // =========================================================================
    int unsigned wr_count;
    int unsigned rd_count;

    int unsigned rd_mismatch;
    int unsigned resp_error;
    int unsigned id_error;
    int unsigned beat_error;

    // =========================================================================
    // UVM
    // =========================================================================
    `uvm_component_utils(axi4_scoreboard)

    function new(string name = "axi4_scoreboard",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        ae_wr = new("ae_wr", this);
        ae_rd = new("ae_rd", this);
    endfunction

    // =========================================================================
    // Write path
    // =========================================================================
    virtual function void write_wr(axi4_wr_seq_item tr);
    
        
        logic [31:0] addr;

        wr_count++;
        `uvm_info("SB_DBG",
        $sformatf("@%0t Scoreboard AWID=0x%0h BID=0x%0h",
                  $time,
                  tr.awid,
                  tr.bid),
        UVM_NONE)

        //----------------------------------------------------------------------
        // Beat count check
        //----------------------------------------------------------------------
        if (tr.wdata.size() != (tr.awlen + 1)) begin
            `uvm_error("SB_WR_BEAT",
                $sformatf("Beat mismatch: got=%0d expected=%0d",
                          tr.wdata.size(),
                          tr.awlen + 1))
            beat_error++;
        end

        //----------------------------------------------------------------------
        // BRESP check
        //----------------------------------------------------------------------
        
        // Do đang mặc định OKLA nên nếu kh thì báo lỗi --> update sau 
        if (tr.bresp !== 2'b00) begin
            `uvm_error("SB_BRESP",
                $sformatf("Unexpected BRESP=%0b AWADDR=0x%0h",
                          tr.bresp,
                          tr.awaddr))
            resp_error++;
        end

        //----------------------------------------------------------------------
        // BID check
        //----------------------------------------------------------------------

        // Check xem  AWID có dc preserve đến tới BID hay không 
        if (tr.bid !== tr.awid) begin
            `uvm_error("SB_BID",
                $sformatf("BID mismatch: expected=0x%0h got=0x%0h",
                          tr.awid,
                          tr.bid))
            id_error++;
        end

        //----------------------------------------------------------------------
        // Update shadow memory
        //----------------------------------------------------------------------
        addr = tr.awaddr;

        foreach (tr.wdata[i]) begin

            shadow_mem[addr >> 2] = tr.wdata[i];

            `uvm_info("SB_WR",
                $sformatf("ShadowMem WR : ADDR=0x%0h DATA=0x%0h",
                          addr,
                          tr.wdata[i]),
                UVM_HIGH)

            case (tr.awburst)

                // FIXED
                2'b00:
                    addr = tr.awaddr;

                // INCR
                2'b01:
                    addr = addr + 4;

                // Match DUT implementation
                2'b10:
                    addr = (addr + 4) & ~(32'h3);

                default:
                    addr = addr + 4;

            endcase

        end

        `uvm_info("SB_WR",
            $sformatf("[%0d] WRITE OK : AWADDR=0x%0h BEATS=%0d",
                      wr_count,
                      tr.awaddr,
                      tr.wdata.size()),
            UVM_MEDIUM)

    endfunction

    // =========================================================================
    // Read path
    // =========================================================================
    virtual function void write_rd(axi4_rd_seq_item tr);

        logic [31:0] addr;
        logic [31:0] expected;
        logic [31:0] word_addr;
         string table;
        string result_str;

        rd_count++;

        //----------------------------------------------------------------------
        // Beat count check
        //----------------------------------------------------------------------
        if (tr.rdata.size() != (tr.arlen + 1)) begin
            `uvm_error("SB_RD_BEAT",
                $sformatf("Beat mismatch: got=%0d expected=%0d",
                          tr.rdata.size(),
                          tr.arlen + 1))
            beat_error++;
        end

        //----------------------------------------------------------------------
        // RRESP check
        //----------------------------------------------------------------------
        if (tr.rresp !== 2'b00) begin
            `uvm_error("SB_RRESP",
                $sformatf("Unexpected RRESP=%0b ARADDR=0x%0h",
                          tr.rresp,
                          tr.araddr))
            resp_error++;
        end

        //----------------------------------------------------------------------
        // RID check
        //----------------------------------------------------------------------
        if (tr.rid !== tr.arid) begin
            `uvm_error("SB_RID",
                $sformatf("RID mismatch: expected=0x%0h got=0x%0h",
                          tr.arid,
                          tr.rid))
            id_error++;
        end

        //----------------------------------------------------------------------
        // Compare data
        //----------------------------------------------------------------------
        addr = tr.araddr;



        table = {
        "\n",
        "===============================================================\n",
        $sformatf(
        "READ CHECK : ARID=0x%0h ARADDR=0x%08h ARLEN=%0d\n",
        tr.arid,
        tr.araddr,
        tr.arlen),
        "===============================================================\n",
        "Beat Addr        Expected    Actual      Result\n",
        "---- ----------  ----------  ----------  ------\n"
    };

    foreach (tr.rdata[i]) begin

        word_addr = addr >> 2;

        //----------------------------------------------------------
        // Get expected data
        //----------------------------------------------------------
        if (shadow_mem.exists(word_addr))
            expected = shadow_mem[word_addr];
        else
            expected = 'hx;

        //----------------------------------------------------------
        // Compare
        //----------------------------------------------------------
        if (tr.rdata[i] === expected) begin
            result_str = "PASS";
        end
        else begin
            result_str = "FAIL";
            rd_mismatch++;
        end

        //----------------------------------------------------------
        // Append row
        //----------------------------------------------------------
        table = {
            table,
            $sformatf(
            "%-4d 0x%08h  0x%08h  0x%08h  %s\n",
            i,
            addr,
            expected,
            tr.rdata[i],
            result_str)
        };

        //----------------------------------------------------------
        // Address update
        //----------------------------------------------------------
        case (tr.arburst)

            // FIXED
            2'b00:
                addr = tr.araddr;

            // INCR
            2'b01:
                addr = addr + 4;

            // Match DUT implementation
            2'b10:
                addr = (addr + 4) & ~(32'h3);

            default:
                addr = addr + 4;

        endcase

    end

    //--------------------------------------------------------------
    // Print table
    //--------------------------------------------------------------
    `uvm_info("SB_RD", table, UVM_MEDIUM)

        endfunction

    // =========================================================================
    // Report
    // =========================================================================
    virtual function void report_phase(uvm_phase phase);

        string msg;

        msg = $sformatf(
            "\n==================================================\n" +
            " Scoreboard Summary\n" +
            "==================================================\n" +
            " Writes       : %0d\n" +
            " Reads        : %0d\n" +
            " Data Errors  : %0d\n" +
            " Resp Errors  : %0d\n" +
            " ID Errors    : %0d\n" +
            " Beat Errors  : %0d\n" +
            "==================================================",
            wr_count,
            rd_count,
            rd_mismatch,
            resp_error,
            id_error,
            beat_error);

        `uvm_info("SB_REPORT", msg, UVM_NONE)

        if ((rd_mismatch == 0) &&
            (resp_error == 0) &&
            (id_error   == 0) &&
            (beat_error == 0))
        begin
            `uvm_info("SB_REPORT",
                      "*** ALL CHECKS PASSED ***",
                      UVM_NONE)
        end
        else begin
            `uvm_error("SB_REPORT",
                       "*** SCOREBOARD FAIL ***")
        end

    endfunction

endclass : axi4_scoreboard