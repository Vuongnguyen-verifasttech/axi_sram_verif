`timescale 1ns/1ps

// =============================================================================
// axi4_coverage.sv
// Functional Coverage — AXI_01 đến AXI_17 (trừ AXI_16)
//
// Connect trong env:
//   axi_agent.ap_wr.connect(coverage.ap_wr);
//   axi_agent.ap_rd.connect(coverage.ap_rd);
//
// Covergroup map:
//   cg_reset          → AXI_01~05 : reset conditions
//   cg_write          → AXI_06,09,12,14 : write protocol
//   cg_read           → AXI_07,10,14 : read protocol
//   cg_integrity      → AXI_08 : write-then-read data match
//   cg_burst_protocol → AXI_09,10,11,12 : burst types x len
//   cg_arbitration    → AXI_13 : concurrent RW
//   cg_backpressure   → AXI_14 : backpressure conditions
//   cg_outstanding    → AXI_15 : ID propagation
//   cg_reset_burst    → AXI_17 : reset during burst
// =============================================================================

class axi4_coverage extends uvm_component;

    `uvm_component_utils(axi4_coverage)

    // =========================================================================
    // Analysis Imp — nhận từ monitor
    // =========================================================================
    `uvm_analysis_imp_decl(_wr)
    `uvm_analysis_imp_decl(_rd)

    uvm_analysis_imp_wr #(axi4_wr_seq_item, axi4_coverage) ap_wr;
    uvm_analysis_imp_rd #(axi4_rd_seq_item, axi4_coverage) ap_rd;

    // =========================================================================
    // Current transaction handles
    // =========================================================================
    axi4_wr_seq_item wr_tr;
    axi4_rd_seq_item rd_tr;

    // Flag: có write gần nhất chưa được pair với read
    bit wr_pending;

    // =========================================================================
    // AXI_01~05 — Reset Coverage
    // Sample thủ công từ reset sequence qua sample()
    // =========================================================================
    covergroup cg_reset;

        // Loại tín hiệu tại thời điểm reset
        cp_reset_during_write: coverpoint wr_tr.awlen {
            bins idle        = {0};         // AXI_01: reset khi idle
            bins single_beat = {0};         // AXI_02: reset giữa single write
            bins burst       = {[1:15]};    // AXI_03/04: reset giữa burst
        }

        // Burst type khi bị reset
        cp_burst_at_reset: coverpoint wr_tr.awburst {
            bins FIXED = {2'b00};
            bins INCR  = {2'b01};
            bins WRAP  = {2'b10};
        }

        // AXI_05: Random reset — cross burst x len
        cx_random_reset: cross cp_burst_at_reset, cp_reset_during_write;

    endgroup : cg_reset

    // =========================================================================
    // AXI_06, AXI_09, AXI_12, AXI_14 — Write Protocol Coverage
    // =========================================================================
    covergroup cg_write;

        // Burst type — AXI_06(INCR len=0), AXI_12(FIXED), AXI_09(INCR)
        cp_awburst: coverpoint wr_tr.awburst {
            bins FIXED = {2'b00};   // AXI_12
            bins INCR  = {2'b01};   // AXI_06, AXI_09
            bins WRAP  = {2'b10};   // AXI_11
        }

        // Burst length
        cp_awlen: coverpoint wr_tr.awlen {
            bins single     = {0};          // AXI_06: len=0
            bins short      = {[1:3]};
            bins medium     = {[4:7]};
            bins long_burst = {[8:15]};     // AXI_09: full range
        }

        // Write response — luôn phải OKAY với SRAM
        cp_bresp: coverpoint wr_tr.bresp {
            bins OKAY   = {2'b00};
            bins SLVERR = {2'b10};
        }

        // AWID range — AXI_15 ID propagation
        cp_awid: coverpoint wr_tr.awid {
            bins id_zero = {0};
            bins id_low  = {[1:7]};
            bins id_high = {[8:14]};
            bins id_max  = {15};
        }

        // Address region trong 4KB SRAM
        cp_awaddr_region: coverpoint wr_tr.awaddr[11:10] {
            bins region_0 = {2'b00};    // 0x000~0x3FF
            bins region_1 = {2'b01};    // 0x400~0x7FF
            bins region_2 = {2'b10};    // 0x800~0xBFF
            bins region_3 = {2'b11};    // 0xC00~0xFFF
        }

        // Cross: burst type x len — AXI_09/12 main coverage
        cx_burst_len: cross cp_awburst, cp_awlen {
            // FIXED: AXI_12
            bins fixed_single = binsof(cp_awburst.FIXED) && binsof(cp_awlen.single);
            bins fixed_short  = binsof(cp_awburst.FIXED) && binsof(cp_awlen.short);
            bins fixed_medium = binsof(cp_awburst.FIXED) && binsof(cp_awlen.medium);
            bins fixed_long   = binsof(cp_awburst.FIXED) && binsof(cp_awlen.long_burst);
            // INCR: AXI_06/09
            bins incr_single  = binsof(cp_awburst.INCR)  && binsof(cp_awlen.single);
            bins incr_short   = binsof(cp_awburst.INCR)  && binsof(cp_awlen.short);
            bins incr_medium  = binsof(cp_awburst.INCR)  && binsof(cp_awlen.medium);
            bins incr_long    = binsof(cp_awburst.INCR)  && binsof(cp_awlen.long_burst);
        }

        // Cross: burst type x response
        cx_burst_resp: cross cp_awburst, cp_bresp;

    endgroup : cg_write

    // =========================================================================
    // AXI_07, AXI_10, AXI_14 — Read Protocol Coverage
    // =========================================================================
    covergroup cg_read;

        // Burst type
        cp_arburst: coverpoint rd_tr.arburst {
            bins FIXED = {2'b00};
            bins INCR  = {2'b01};   // AXI_07, AXI_10
            bins WRAP  = {2'b10};
        }

        // Burst length
        cp_arlen: coverpoint rd_tr.arlen {
            bins single     = {0};          // AXI_07
            bins short      = {[1:3]};
            bins medium     = {[4:7]};
            bins long_burst = {[8:15]};     // AXI_10 full range
        }

        // Read response
        cp_rresp: coverpoint rd_tr.rresp {
            bins OKAY   = {2'b00};
            bins SLVERR = {2'b10};
        }

        // ARID — AXI_15
        cp_arid: coverpoint rd_tr.arid {
            bins id_zero = {0};
            bins id_low  = {[1:7]};
            bins id_high = {[8:14]};
            bins id_max  = {15};
        }

        // Address region
        cp_araddr_region: coverpoint rd_tr.araddr[11:10] {
            bins region_0 = {2'b00};
            bins region_1 = {2'b01};
            bins region_2 = {2'b10};
            bins region_3 = {2'b11};
        }

        // Cross: burst type x len — AXI_10 main
        cx_burst_len: cross cp_arburst, cp_arlen {
            bins incr_single  = binsof(cp_arburst.INCR) && binsof(cp_arlen.single);
            bins incr_short   = binsof(cp_arburst.INCR) && binsof(cp_arlen.short);
            bins incr_medium  = binsof(cp_arburst.INCR) && binsof(cp_arlen.medium);
            bins incr_long    = binsof(cp_arburst.INCR) && binsof(cp_arlen.long_burst);
            bins fixed_single = binsof(cp_arburst.FIXED) && binsof(cp_arlen.single);
            bins fixed_short  = binsof(cp_arburst.FIXED) && binsof(cp_arlen.short);
        }

    endgroup : cg_read

    // =========================================================================
    // AXI_08 — Write-Read Data Integrity Coverage
    // Sample khi read xảy ra tại cùng địa chỉ với write trước đó
    // =========================================================================
    covergroup cg_integrity;

        // Burst type trong integrity test
        cp_burst: coverpoint wr_tr.awburst {
            bins FIXED = {2'b00};
            bins INCR  = {2'b01};
            bins WRAP  = {2'b10};
        }

        // Số beats — verify data qua nhiều beat
        cp_len: coverpoint wr_tr.awlen {
            bins single = {0};
            bins short  = {[1:3]};
            bins medium = {[4:7]};
            bins long_b = {[8:15]};
        }

        // Address region — verify ghi/đọc đúng vùng nhớ
        cp_addr_region: coverpoint wr_tr.awaddr[11:10] {
            bins region_0 = {2'b00};
            bins region_1 = {2'b01};
            bins region_2 = {2'b10};
            bins region_3 = {2'b11};
        }

        // Cross: đảm bảo integrity test bao phủ đủ combo
        cx_integrity_combo: cross cp_burst, cp_len, cp_addr_region;

    endgroup : cg_integrity

    // =========================================================================
    // AXI_11, AXI_12 — Burst Protocol Coverage (WRAP + FIXED detail)
    // =========================================================================
    covergroup cg_burst_protocol;

        // WRAP burst boundary — AXI_11
        cp_wrap_len: coverpoint wr_tr.awlen {
            bins wrap_2  = {1};     // 2 beats
            bins wrap_4  = {3};     // 4 beats
            bins wrap_8  = {7};     // 8 beats
            bins wrap_16 = {15};    // 16 beats
        }

        // FIXED burst — AXI_12: địa chỉ không đổi qua nhiều beat
        cp_fixed_len: coverpoint wr_tr.awlen {
            bins fixed_1  = {0};
            bins fixed_4  = {3};
            bins fixed_8  = {7};
            bins fixed_16 = {15};
        }

        // Burst type
        cp_burst: coverpoint wr_tr.awburst {
            bins FIXED = {2'b00};
            bins INCR  = {2'b01};
            bins WRAP  = {2'b10};
        }

        // Cross: burst type x boundary len
        cx_burst_boundary: cross cp_burst, cp_wrap_len;

    endgroup : cg_burst_protocol

    // =========================================================================
    // AXI_13 — Concurrent Write + Read (Arbitration) Coverage
    // =========================================================================
    covergroup cg_arbitration;

        // Write burst type khi concurrent
        cp_wr_burst: coverpoint wr_tr.awburst {
            bins FIXED = {2'b00};
            bins INCR  = {2'b01};
        }

        // Write len khi concurrent
        cp_wr_len: coverpoint wr_tr.awlen {
            bins single = {0};
            bins burst  = {[1:15]};
        }

        // Read len khi concurrent
        cp_rd_len: coverpoint rd_tr.arlen {
            bins single = {0};
            bins burst  = {[1:15]};
        }

        // Cross: write x read — arbiter phải xử lý đúng mọi combo
        cx_concurrent: cross cp_wr_burst, cp_wr_len, cp_rd_len;

    endgroup : cg_arbitration

    // =========================================================================
    // AXI_14 — Backpressure Coverage
    // =========================================================================
    covergroup cg_backpressure;

        // Burst type dưới backpressure
        cp_burst: coverpoint wr_tr.awburst {
            bins FIXED = {2'b00};
            bins INCR  = {2'b01};
        }

        // Len dưới backpressure
        cp_len: coverpoint wr_tr.awlen {
            bins single = {0};
            bins short  = {[1:3]};
            bins medium = {[4:7]};
            bins long_b = {[8:15]};
        }

        // Response vẫn OKAY dù có stall
        cp_bresp: coverpoint wr_tr.bresp {
            bins OKAY = {2'b00};
        }

        // Cross: burst x len dưới backpressure
        cx_bp_combo: cross cp_burst, cp_len;

    endgroup : cg_backpressure

    // =========================================================================
    // AXI_15 — Multiple Outstanding / ID Propagation Coverage
    // =========================================================================
    covergroup cg_outstanding;

        // AWID values — verify nhiều ID khác nhau
        cp_awid: coverpoint wr_tr.awid {
            bins id_0   = {0};
            bins id_mid = {[1:14]};
            bins id_max = {15};
        }

        // BID phải match AWID — verify propagation
        cp_bid: coverpoint wr_tr.bid {
            bins id_0   = {0};
            bins id_mid = {[1:14]};
            bins id_max = {15};
        }

        // Cross: AWID phải luôn = BID
        cx_id_propagation: cross cp_awid, cp_bid {
            // Chỉ legal khi AWID == BID
            bins match_0   = binsof(cp_awid.id_0)   && binsof(cp_bid.id_0);
            bins match_mid = binsof(cp_awid.id_mid)  && binsof(cp_bid.id_mid);
            bins match_max = binsof(cp_awid.id_max)  && binsof(cp_bid.id_max);
            // Mismatch = bug — illegal bins
            illegal_bins mismatch_0_mid = binsof(cp_awid.id_0) && binsof(cp_bid.id_mid);
            illegal_bins mismatch_0_max = binsof(cp_awid.id_0) && binsof(cp_bid.id_max);
            illegal_bins mismatch_max_0 = binsof(cp_awid.id_max) && binsof(cp_bid.id_0);
        }

    endgroup : cg_outstanding

    // =========================================================================
    // AXI_17 — Reset During Burst Coverage
    // =========================================================================
    covergroup cg_reset_burst;

        // Burst type khi reset inject
        cp_burst_at_reset: coverpoint wr_tr.awburst {
            bins FIXED = {2'b00};
            bins INCR  = {2'b01};
            bins WRAP  = {2'b10};
        }

        // Len khi reset — reset có thể mid-burst
        cp_len_at_reset: coverpoint wr_tr.awlen {
            bins single = {0};
            bins short  = {[1:3]};
            bins medium = {[4:7]};
            bins long_b = {[8:15]};
        }

        // Cross: đảm bảo reset được test ở nhiều điểm trong burst
        cx_reset_point: cross cp_burst_at_reset, cp_len_at_reset;

    endgroup : cg_reset_burst

    // =========================================================================
    // Constructor
    // =========================================================================
    function new(string name = "axi4_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_reset          = new();
        cg_write          = new();
        cg_read           = new();
        cg_integrity      = new();
        cg_burst_protocol = new();
        cg_arbitration    = new();
        cg_backpressure   = new();
        cg_outstanding    = new();
        cg_reset_burst    = new();
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_wr = new("ap_wr", this);
        ap_rd = new("ap_rd", this);
    endfunction

    // =========================================================================
    // Write callbacks
    // =========================================================================
    virtual function void write_wr(axi4_wr_seq_item tr);
        wr_tr      = tr;
        wr_pending = 1;

        cg_write.sample();
        cg_reset.sample();
        cg_burst_protocol.sample();
        cg_backpressure.sample();
        cg_outstanding.sample();
        cg_reset_burst.sample();
        cg_arbitration.sample();
    endfunction

    virtual function void write_rd(axi4_rd_seq_item tr);
        rd_tr = tr;

        cg_read.sample();
        cg_arbitration.sample();

        // Integrity: chỉ sample khi read cùng địa chỉ với write trước đó
        if (wr_pending && wr_tr != null &&
            wr_tr.awaddr == rd_tr.araddr &&
            wr_tr.awlen  == rd_tr.arlen)
        begin
            cg_integrity.sample();
            wr_pending = 0;
        end
    endfunction

    // =========================================================================
    // Report Phase
    // =========================================================================
    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf({
            "\n╔══════════════════════════════════════╗\n",
            "║       FUNCTIONAL COVERAGE REPORT     ║\n",
            "╠══════════════════════════════════════╣\n",
            "║ AXI_01~05 cg_reset          : %5.1f%% ║\n",
            "║ AXI_06,09,12,14 cg_write    : %5.1f%% ║\n",
            "║ AXI_07,10,14 cg_read        : %5.1f%% ║\n",
            "║ AXI_08 cg_integrity         : %5.1f%% ║\n",
            "║ AXI_11,12 cg_burst_protocol : %5.1f%% ║\n",
            "║ AXI_13 cg_arbitration       : %5.1f%% ║\n",
            "║ AXI_14 cg_backpressure      : %5.1f%% ║\n",
            "║ AXI_15 cg_outstanding       : %5.1f%% ║\n",
            "║ AXI_17 cg_reset_burst       : %5.1f%% ║\n",
            "╚══════════════════════════════════════╝"},
            cg_reset.get_coverage(),
            cg_write.get_coverage(),
            cg_read.get_coverage(),
            cg_integrity.get_coverage(),
            cg_burst_protocol.get_coverage(),
            cg_arbitration.get_coverage(),
            cg_backpressure.get_coverage(),
            cg_outstanding.get_coverage(),
            cg_reset_burst.get_coverage()),
            UVM_NONE)
    endfunction

endclass : axi4_coverage