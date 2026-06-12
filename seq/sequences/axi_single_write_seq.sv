`timescale 1ns/1ps

class axi4_single_wr_seq extends uvm_sequence #(axi4_wr_seq_item);

    `uvm_object_utils(axi4_single_wr_seq)

    axi4_wr_seq_item req;

    function new(string name="axi4_single_wr_seq");
        super.new(name);
    endfunction

    virtual task body();

        if(req == null)
        begin
            req = axi4_wr_seq_item::type_id::create("req");

            if(!req.randomize())
                `uvm_fatal(get_type_name(),
                           "Randomization failed")
        end

        start_item(req);
        finish_item(req);

        `uvm_info(get_type_name(),
                  $sformatf("WRITE sent: %s",
                            req.convert2string()),
                  UVM_MEDIUM)

    endtask

endclass