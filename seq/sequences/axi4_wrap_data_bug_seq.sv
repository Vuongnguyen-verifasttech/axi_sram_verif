`timescale 1ns/1ps

// =============================================================================
// axi4_wrap_data_bug_seq.sv
// WRAP bug lo o tang DATA (khong chi dia chi).
//
// Y tuong:
//   - Test wrap_burst cu ghi WRAP + doc WRAP -> ca hai cung "sai" y het (DUT
//     khong wrap) nen tu nhat quan -> data luon khop, bug chi lo o dia chi
//     (AXI4_IF_WRAP). Muon bug lo o DATA thi phai TACH kieu burst ghi/doc.
//
//   - O day: GHI bang INCR (dung, khong dinh bug wrap) voi data = CHINH DIA
//     CHI cua no, phu 2 vung wrap. Sau do DOC bang WRAP tu GIUA vung.
//       * Spec ky vong beat wrap doc data tai dia chi da wrap ve boundary.
//       * DUT (khong wrap) doc tiep ra NGOAI vung -> tra data cua dia chi SAI.
//       * Vi data = dia chi, Expected (spec addr) != Actual (dut addr) -> FAIL,
//         va gia tri hien thi ra chinh la dia chi -> thay ro DUT doc nham o dau.
//
// Ket qua mong doi: bang SB_RD co cac beat FAIL o phan wrap, cot Expected hien
// dia chi wrap dung spec, cot Actual hien dia chi INCR sai cua DUT.
// =============================================================================

class axi4_wrap_data_bug_seq extends axi4_base_seq;

    `uvm_object_utils(axi4_wrap_data_bug_seq)

    int unsigned n_trans = 10;

    // beats hop le WRAP: {2,4,8,16} -> awlen {1,3,7,15}
    int unsigned valid_awlen[$] = '{1, 3, 7, 15};

    function new(string name = "axi4_wrap_data_bug_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4_wr_seq_item   wr_req;
        axi4_rd_seq_item   rd_req;
        axi4_single_wr_seq wr_seq;
        axi4_single_rd_seq rd_seq;

        super.body();

        `uvm_info(get_type_name(),
            $sformatf("START WRAP DATA BUG: %0d transactions (expose wrap bug in DATA)", n_trans),
            UVM_LOW)

        repeat (n_trans) begin

            int unsigned awlen_val;
            int unsigned beats;
            int unsigned wrap_len;
            int unsigned setup_beats;
            int unsigned max_bidx;
            int unsigned offset_idx;
            logic [31:0] boundary;
            logic [31:0] rd_start;

            awlen_val   = valid_awlen[$urandom_range(0, 3)];
            beats       = awlen_val + 1;
            wrap_len    = beats * 4;
            setup_beats = 2 * beats;                 // phu CA vung wrap lan vung
                                                     // phia sau ma DUT doc nham

            // boundary align theo wrap_len, con du cho 2 vung trong SRAM 4KB
            max_bidx  = (4096 - 2 * wrap_len) / wrap_len;
            boundary  = $urandom_range(0, max_bidx) * wrap_len;

            // read start GIUA vung (khong o boundary) -> chac chan wrap giua burst
            offset_idx = $urandom_range(1, beats - 1);
            rd_start   = boundary + offset_idx * 4;

            // -----------------------------------------------------------------
            // Setup: GHI INCR, data = dia chi cua chinh no, phu [boundary, +2 vung)
            // -----------------------------------------------------------------
            wr_req = axi4_wr_seq_item::type_id::create("wr_req");
            wr_req.c_len_range.constraint_mode(0);   // cho phep awlen > 15 (2*beats)

            if (!wr_req.randomize() with {
                    awburst == 2'b01;                 // INCR (dung, khong dinh bug)
                    awlen   == setup_beats - 1;
                    awaddr  == boundary;
                })
                `uvm_fatal(get_type_name(), "setup WR randomize failed")

            // data = chinh dia chi -> de nhin ra DUT doc nham o dau
            foreach (wr_req.wdata[i])
                wr_req.wdata[i] = boundary + i * 4;

            wr_seq = axi4_single_wr_seq::type_id::create("wr_seq");
            wr_seq.req = wr_req;
            wr_seq.start(vseqr.wr_seqr);

            // -----------------------------------------------------------------
            // Read WRAP tu GIUA vung -> DUT khong wrap -> doc data SAI
            // -----------------------------------------------------------------
            rd_req = axi4_rd_seq_item::type_id::create("rd_req");
            rd_req.c_burst_type.constraint_mode(0);  // cho phep WRAP (2'b10)

            if (!rd_req.randomize() with {
                    arburst == 2'b10;
                    arlen   == awlen_val;
                    araddr  == rd_start;
                })
                `uvm_fatal(get_type_name(), "WRAP RD randomize failed")

            rd_seq = axi4_single_rd_seq::type_id::create("rd_seq");
            rd_seq.req = rd_req;
            rd_seq.start(vseqr.rd_seqr);

            `uvm_info(get_type_name(),
                $sformatf("WRAP-DATA: boundary=0x%0h rd_start=0x%0h beats=%0d wrap_top=0x%0h | beat wrap se lech: spec ve boundary, DUT doc tiep",
                          boundary, rd_start, beats, boundary + wrap_len),
                UVM_MEDIUM)

        end

        `uvm_info(get_type_name(), "DONE WRAP DATA BUG", UVM_LOW)

    endtask

endclass : axi4_wrap_data_bug_seq
