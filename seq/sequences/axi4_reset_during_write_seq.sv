class axi4_reset_during_write_seq extends axi4_base_seq;

`uvm_object_utils(axi4_reset_during_write_seq)

function new(string name = "axi4_reset_during_wr_seq");
    super.new(name);
endfunction

virtual task body();

    axi4_single_wr_seq wr_seq;
    axi4_reset_seq        rst_seq;

    super.body();

    wr_seq  = axi4_single_wr_seq::type_id::create("wr_seq");
    rst_seq = axi4_reset_seq::type_id::create("rst_seq");

    //-----------------------------------------
    // Start write then inject reset
    //-----------------------------------------
    fork

        begin
            wr_seq.start(vseqr);
        end

        begin
// MỚI — chờ AW handshake xảy ra rồi mới inject reset
@(posedge vseqr.vif.i_clk iff (vseqr.vif.awvalid && vseqr.vif.awready));
// Thêm vài cycle nữa để vào W channel
repeat (3) @(posedge vseqr.vif.i_clk);

            `uvm_info(get_type_name(),
                      "Inject reset during WRITE transaction",
                      UVM_LOW)

            rst_seq.start(vseqr);
        end

    join_any
    // Sát tử luồng còn lại (wr_seq) đang bị kẹt lửng lơ
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

    if (vseqr.vif.awfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "AW FIFO not empty after reset")

    if (vseqr.vif.wfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "W FIFO not empty after reset")

    if (vseqr.vif.bfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "B FIFO not empty after reset")

    `uvm_info(get_type_name(),
              "Reset during write test PASSED",
              UVM_LOW)

endtask

endclass
