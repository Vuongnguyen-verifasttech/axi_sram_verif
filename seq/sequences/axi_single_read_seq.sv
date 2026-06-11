`timescale 1ns/1ps

class axi4_single_rd_seq extends uvm_sequence #(axi4_rd_seq_item);

    `uvm_object_utils(axi4_single_rd_seq)

    int unsigned num_transactions = 10;

    function new(string name="axi4_single_rd_seq");
        super.new(name);
    endfunction

    virtual task body();

        repeat(num_transactions) begin

            axi4_rd_seq_item tr;

            tr = axi4_rd_seq_item::type_id::create("tr");

            start_item(tr);

            if(!tr.randomize())
                `uvm_fatal(get_type_name(),
                           "Randomization failed")

            finish_item(tr);

            `uvm_info(get_type_name(),
                      $sformatf("READ sent: %s",
                                tr.convert2string()),
                      UVM_MEDIUM)

        end

    endtask

endclass