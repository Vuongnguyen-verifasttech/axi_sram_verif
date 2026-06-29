`timescale 1ns/1ps

// =============================================================================
// axi4_rtl_bug001_seq.sv
// Expose RTL_BUG_001: reg_rd_pending chỉ cho 1 beat/burst
//
// 3 sub-test, mỗi cái dùng địa chỉ riêng để không overlap:
//   Case A: arlen=7  (8 beats)  — original, trigger tại beat[3], beat[7]
//   Case B: arlen=15 (16 beats) — trigger tại beat[3,7,11,15]
//   Case C: arlen=3  (4 beats)  — boundary: đúng 1 lần trigger tại beat[3]
// =============================================================================

class axi4_rtl_bug001_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_rtl_bug001_seq)

    // -------------------------------------------------------------------------
    // Parameters cho từng case — địa chỉ cách nhau 0x100 để không overlap
    // -------------------------------------------------------------------------
    localparam logic [31:0] BASE_ADDR_A = 32'h0000_0100;  // Case A: 8  beats
    localparam logic [31:0] BASE_ADDR_B = 32'h0000_0200;  // Case B: 16 beats
    localparam logic [31:0] BASE_ADDR_C = 32'h0000_0300;  // Case C: 4  beats

    localparam int unsigned NUM_BEATS_A = 8;
    localparam int unsigned NUM_BEATS_B = 16;
    localparam int unsigned NUM_BEATS_C = 4;

    // Known data mỗi case — pattern DEAD_xxyy (xx=case, yy=beat index+1)
    logic [31:0] known_data_A [NUM_BEATS_A] = '{
        32'hDEAD_A001, 32'hDEAD_A002, 32'hDEAD_A003, 32'hDEAD_A004,
        32'hDEAD_A005, 32'hDEAD_A006, 32'hDEAD_A007, 32'hDEAD_A008
    };

    logic [31:0] known_data_B [NUM_BEATS_B] = '{
        32'hDEAD_B001, 32'hDEAD_B002, 32'hDEAD_B003, 32'hDEAD_B004,
        32'hDEAD_B005, 32'hDEAD_B006, 32'hDEAD_B007, 32'hDEAD_B008,
        32'hDEAD_B009, 32'hDEAD_B00A, 32'hDEAD_B00B, 32'hDEAD_B00C,
        32'hDEAD_B00D, 32'hDEAD_B00E, 32'hDEAD_B00F, 32'hDEAD_B010
    };

    logic [31:0] known_data_C [NUM_BEATS_C] = '{
        32'hDEAD_C001, 32'hDEAD_C002, 32'hDEAD_C003, 32'hDEAD_C004
    };

    function new(string name = "axi4_rtl_bug001_seq");
        super.new(name);
    endfunction

    // =========================================================================
    // body
    // =========================================================================
    virtual task body();

        super.body();

        `uvm_info(get_type_name(),
            "START RTL_BUG_001: 3 burst cases (arlen=7 / arlen=15 / arlen=3)",
            UVM_LOW)

        run_case("A", BASE_ADDR_A, NUM_BEATS_A, known_data_A);
        run_case("B", BASE_ADDR_B, NUM_BEATS_B, known_data_B);
        run_case("C", BASE_ADDR_C, NUM_BEATS_C, known_data_C);

        `uvm_info(get_type_name(), "DONE RTL_BUG_001 — all cases complete", UVM_LOW)

    endtask

    // =========================================================================
    // Task chạy 1 case: write single-beat × N, read burst arlen=N-1
    // =========================================================================
    task automatic run_case(
        string        case_name,
        logic [31:0]  base_addr,
        int unsigned  num_beats,
        logic [31:0]  known_data[]
    );

        // ---------------------------------------------------------------------
        // Step 1: Write từng beat riêng lẻ (awlen=0) để isolate write path
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(),
            $sformatf("=== Case %s: WRITE %0d single-beat @ base=0x%08h ===",
                      case_name, num_beats, base_addr),
            UVM_LOW)

        for (int i = 0; i < num_beats; i++) begin
            axi4_wr_seq_item   wr_req;
            axi4_single_wr_seq wr_seq;

            wr_req = axi4_wr_seq_item::type_id::create(
                         $sformatf("wr_%s_%0d", case_name, i));

            if (!wr_req.randomize() with {
                    awburst    == 2'b01;
                    awlen      == 0;
                    awaddr     == base_addr + i * 4;
                    wdata.size() == 1;
                    wdata[0]   == known_data[i];
                })
                `uvm_fatal(get_type_name(),
                    $sformatf("Case %s WR[%0d] randomize failed", case_name, i))

            wr_seq = axi4_single_wr_seq::type_id::create(
                         $sformatf("wr_seq_%s_%0d", case_name, i));
            wr_seq.req = wr_req;
            wr_seq.start(vseqr.wr_seqr);

            `uvm_info(get_type_name(),
                $sformatf("  WR[%0d]: ADDR=0x%08h DATA=0x%08h",
                          i, base_addr + i * 4, known_data[i]),
                UVM_MEDIUM)
        end

        // 2 cycle delay cho DUT commit write vào SRAM
        #20;

        // ---------------------------------------------------------------------
        // Step 2: Read lại bằng 1 burst arlen = num_beats-1
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(),
            $sformatf("=== Case %s: READ burst arlen=%0d @ base=0x%08h ===",
                      case_name, num_beats - 1, base_addr),
            UVM_LOW)

        begin
            axi4_rd_seq_item   rd_req;
            axi4_single_rd_seq rd_seq;
            int                fail_cnt;
            int                expected_fail_beats[$];

            // Tính trước các beat dự kiến bị bug (cứ 4 beat thì fail 1)
            // beat[3], beat[7], beat[11], beat[15]
            for (int i = 3; i < num_beats; i += 4)
                expected_fail_beats.push_back(i);

            rd_req = axi4_rd_seq_item::type_id::create(
                         $sformatf("rd_%s", case_name));

            if (!rd_req.randomize() with {
                    arburst == 2'b01;
                    arlen   == num_beats - 1;
                    araddr  == base_addr;
                })
                `uvm_fatal(get_type_name(),
                    $sformatf("Case %s RD randomize failed", case_name))

            rd_seq = axi4_single_rd_seq::type_id::create(
                         $sformatf("rd_seq_%s", case_name));
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

            // -----------------------------------------------------------------
            // Step 3: Inline checker
            // -----------------------------------------------------------------
            `uvm_info(get_type_name(),
                $sformatf("--- Case %s READ BACK CHECK (expected fail beats: %p) ---",
                          case_name, expected_fail_beats),
                UVM_LOW)

            fail_cnt = 0;

            foreach (rd_req.rdata[i]) begin
                if (rd_req.rdata[i] === known_data[i]) begin
                    `uvm_info(get_type_name(),
                        $sformatf("  beat[%0d] PASS: ADDR=0x%08h exp=0x%08h got=0x%08h",
                                  i, base_addr + i * 4,
                                  known_data[i], rd_req.rdata[i]),
                        UVM_MEDIUM)
                end else begin
                    `uvm_error(get_type_name(),
                        $sformatf("  beat[%0d] FAIL: ADDR=0x%08h exp=0x%08h got=0x%08h — RTL_BUG_001 Case %s",
                                  i, base_addr + i * 4,
                                  known_data[i], rd_req.rdata[i],
                                  case_name))
                    fail_cnt++;
                end
            end

            // Check beat count (RLAST position)
            if (rd_req.rdata.size() != num_beats)
                `uvm_error(get_type_name(),
                    $sformatf("Case %s BEAT COUNT FAIL: exp=%0d got=%0d — RLAST sai vị trí",
                              case_name, num_beats, rd_req.rdata.size()))

            // Summary per case
            `uvm_info(get_type_name(),
                $sformatf("=== Case %s SUMMARY: %0d/%0d beats FAIL ===",
                          case_name, fail_cnt, num_beats),
                UVM_LOW)
        end

    endtask : run_case

endclass : axi4_rtl_bug001_seq