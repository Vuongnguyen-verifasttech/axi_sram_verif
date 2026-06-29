`timescale 1ns/1ps

// =============================================================================
// axi4_rtl_bug001_seq.sv
// Expose RTL_BUG_001: reg_rd_pending chỉ cho 1 beat/burst
//
// Flow:
//   1. Write known data vào 8 địa chỉ liên tiếp (INCR, single beat)
//   2. Read lại bằng 1 burst arlen=7 (8 beats)
//   3. Nếu bug tồn tại: chỉ beat 0 đúng, beat 1..7 sai hoặc rlast sai vị trí
// =============================================================================

class axi4_rtl_bug001_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_rtl_bug001_seq)

    // Base address và known data cố định — dễ trace trên waveform
    localparam logic [31:0] BASE_ADDR  = 32'h0000_0100;
    localparam int unsigned NUM_BEATS  = 8;             // arlen = 7

    logic [31:0] known_data [NUM_BEATS] = '{
        32'hDEAD_0001,
        32'hDEAD_0002,
        32'hDEAD_0003,
        32'hDEAD_0004,
        32'hDEAD_0005,
        32'hDEAD_0006,
        32'hDEAD_0007,
        32'hDEAD_0008
    };

    function new(string name = "axi4_rtl_bug001_seq");
        super.new(name);
    endfunction

    virtual task body();

        super.body();

        `uvm_info(get_type_name(),
            "START RTL_BUG_001 expose: write 8 known beats, read back as 1 burst",
            UVM_LOW)

        // ------------------------------------------------------------------
        // Step 1: Write 8 địa chỉ liên tiếp, mỗi địa chỉ 1 beat
        // Dùng single-beat write để tránh bất kỳ bug burst write nào
        // ------------------------------------------------------------------
        for (int i = 0; i < NUM_BEATS; i++) begin
            axi4_wr_seq_item   wr_req;
            axi4_single_wr_seq wr_seq;

            wr_req = axi4_wr_seq_item::type_id::create($sformatf("wr_req_%0d", i));
            if (!wr_req.randomize() with {
                    awburst    == 2'b01;            // INCR
                    awlen      == 0;                // single beat
                    awaddr     == BASE_ADDR + i*4;
                    wdata.size() == 1;
                    wdata[0]   == known_data[i];    // data cố định
                })
                `uvm_fatal(get_type_name(), "WR randomize failed")

            wr_seq = axi4_single_wr_seq::type_id::create($sformatf("wr_seq_%0d", i));
            wr_seq.req = wr_req;
            wr_seq.start(vseqr.wr_seqr);

            `uvm_info(get_type_name(),
                $sformatf("  WR[%0d]: ADDR=0x%08h DATA=0x%08h",
                          i, BASE_ADDR + i*4, known_data[i]),
                UVM_MEDIUM)
        end

        // ------------------------------------------------------------------
        // Step 2: Read lại toàn bộ bằng 1 burst arlen=7
        // Nếu DUT đúng: rdata[0..7] = known_data[0..7]
        // Nếu bug:      rdata[1..7] sai hoặc rlast không đúng beat 7
        // ------------------------------------------------------------------
        begin
            axi4_rd_seq_item   rd_req;
            axi4_single_rd_seq rd_seq;

            rd_req = axi4_rd_seq_item::type_id::create("rd_req");
            if (!rd_req.randomize() with {
                    arburst == 2'b01;
                    arlen   == NUM_BEATS - 1;   // arlen=7 → 8 beats
                    araddr  == BASE_ADDR;
                })
                `uvm_fatal(get_type_name(), "RD randomize failed")

            rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

            // ------------------------------------------------------------------
            // Step 3: Inline checker — không phụ thuộc scoreboard
            // ------------------------------------------------------------------
            `uvm_info(get_type_name(),
                "READ BACK CHECK (RTL_BUG_001):", UVM_LOW)

            foreach (rd_req.rdata[i]) begin
                if (rd_req.rdata[i] === known_data[i])
                    `uvm_info(get_type_name(),
                        $sformatf("  beat[%0d] PASS: ADDR=0x%08h expected=0x%08h actual=0x%08h",
                                  i, BASE_ADDR + i*4, known_data[i], rd_req.rdata[i]),
                        UVM_MEDIUM)
                else
                    `uvm_error(get_type_name(),
                        $sformatf("  beat[%0d] FAIL: ADDR=0x%08h expected=0x%08h actual=0x%08h — RTL_BUG_001",
                                  i, BASE_ADDR + i*4, known_data[i], rd_req.rdata[i]))
            end

            // Check số beat nhận được
            if (rd_req.rdata.size() != NUM_BEATS)
                `uvm_error(get_type_name(),
                    $sformatf("BEAT COUNT FAIL: expected=%0d actual=%0d — RLAST sai vị trí",
                              NUM_BEATS, rd_req.rdata.size()))
        end

        `uvm_info(get_type_name(), "DONE RTL_BUG_001 expose", UVM_LOW)

    endtask

endclass : axi4_rtl_bug001_seq