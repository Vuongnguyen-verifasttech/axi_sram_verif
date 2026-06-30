class axi4_reset_during_read_seq extends axi4_base_seq;

`uvm_object_utils(axi4_reset_during_read_seq)

function new(string name = "axi4_reset_during_read_seq");
    super.new(name);
endfunction

virtual task body();

    axi4_single_rd_seq rd_seq;
    axi4_reset_seq        rst_seq;

    super.body();

    // Đảm bảo power-on reset (từ tb_top) đã hoàn toàn settle
    // trước khi bắt đầu transaction thử nghiệm của test này.
    // Tránh power-on reset chồng chéo với AR handshake gây sequence
    // bị "chết" sớm mà không phải do logic test inject.
    repeat (10) @(posedge vseqr.vif.i_clk);

    rd_seq  = axi4_single_rd_seq::type_id::create("rd_seq");
    rst_seq = axi4_reset_seq::type_id::create("rst_seq");

    //-----------------------------------------
    // Start write then inject reset
    //-----------------------------------------
    fork

        begin
            rd_seq.start(vseqr.rd_seqr);
        end

        begin
            // Wait until read is in progress
            repeat (20)
                @(posedge vseqr.vif.i_clk);

            `uvm_info(get_type_name(),
                      "Inject reset during READ transaction",
                      UVM_LOW)

            rst_seq.start(vseqr);
        end

    join_any
    // Kill luồng còn lại (rd_seq) đang bị kẹt lửng lơ
    disable fork; 

    //-----------------------------------------
    // Post-reset checks
    //-----------------------------------------
    `uvm_info(get_type_name(), "Moving to post-reset assertions check...", UVM_LOW)

    //-----------------------------------------
    // Post-reset checks
    //-----------------------------------------

    repeat (5)
        @(posedge vseqr.vif.i_clk);

    if (vseqr.vif.awready !== 1'b1)
        `uvm_error(get_type_name(),
                   "AWREADY is not HIGH after reset")

    if (vseqr.vif.arready !== 1'b1)
        `uvm_error(get_type_name(),
                   "ARREADY is not HIGH after reset")

    if (vseqr.vif.bvalid !== 1'b0)
        `uvm_error(get_type_name(),
                   "Unexpected BVALID after reset")

    if (vseqr.vif.rvalid !== 1'b0)
        `uvm_error(get_type_name(),
                   "Unexpected RVALID after reset")

    if (vseqr.vif.arfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "AR FIFO not empty after reset")

    if (vseqr.vif.rfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "R FIFO not empty after reset")

    // Write path không tham gia test này nhưng vẫn check
    // để đảm bảo reset không gây side-effect chéo channel
    if (vseqr.vif.awfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "AW FIFO not empty after reset (cross-channel side effect)")

    if (vseqr.vif.wfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "W FIFO not empty after reset (cross-channel side effect)")

    `uvm_info(get_type_name(),
              "Reset during read test PASSED",
              UVM_LOW)

endtask

endclass