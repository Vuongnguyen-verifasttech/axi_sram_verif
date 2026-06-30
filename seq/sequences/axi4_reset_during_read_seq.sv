class axi4_reset_during_read_seq extends axi4_base_seq;

`uvm_object_utils(axi4_reset_during_read_seq)

function new(string name = "axi4_reset_during_read_seq");
    super.new(name);
endfunction

virtual task body();

    axi4_single_rd_seq rd_seq;
    axi4_reset_seq        rst_seq;

    super.body();

    rd_seq  = axi4_single_rd_seq::type_id::create("rd_seq");
    rst_seq = axi4_reset_seq::type_id::create("rst_seq");

    //-----------------------------------------
    // Start write then inject reset
    //-----------------------------------------
    fork

        begin
            rd_seq.start(vseqr);
        end

        begin
            // Wait until write is in progress
            repeat (20)
                @(posedge vseqr.vif.i_clk);

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

    if (vseqr.vif.arfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "AR FIFO not empty after reset")

    if (vseqr.vif.rfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "R FIFO not empty after reset")

    if (vseqr.vif.bfifo_empty !== 1'b1)
        `uvm_error(get_type_name(),
                   "B FIFO not empty after reset")

    `uvm_info(get_type_name(),
              "Reset during read test PASSED",
              UVM_LOW)

endtask

endclass
