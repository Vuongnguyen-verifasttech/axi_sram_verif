`timescale 1ns/1ps

// =============================================================================
// axi4_rd_monitor.sv
//
// AXI4 Read Monitor
//
// DUT assumptions:
//   - Single outstanding read transaction
//   - No read interleaving
//   - Responses returned in-order
//
// Architecture:
//   ar_thread() : capture AR request
//   r_thread()  : capture R response burst
//
// Mailbox used only to pass AR information to R thread.
//
// Analysis Ports:
//   ap_ar : AR transactions for coverage
//   ap_rd : Complete AR + R transaction for scoreboard
//
// Future improvements:
//   - Multiple outstanding reads
//   - Out-of-order response handling
//   - RID based transaction tracking
// =============================================================================

/*
                                AR Channel
                                    |
                                    v
                                ar_thread()
                                    |
                                    v
                                mailbox
                                    |
                                    v
                                r_thread()
                                    |
                                    +--> collect RDATA
                                    +--> check RID
                                    +--> check RLAST
                                    +--> check beat count
                                    |
                                    v
                                ap_rd.write()
                                    |
                                    v
                                Scoreboard
*/

class axi4_rd_monitor extends uvm_monitor;

    //==========================================================================
    // Config / Interface
    //==========================================================================
    axi4_agent_cfg         cfg;
    virtual axi4_if.slave  vif;

    //==========================================================================
    // Analysis Ports
    //==========================================================================
    uvm_analysis_port #(axi4_rd_seq_item) ap_ar;
    uvm_analysis_port #(axi4_rd_seq_item) ap_rd;

    //==========================================================================
    // Internal mailbox
    //==========================================================================
    mailbox #(axi4_rd_seq_item) mbx_ar;

    //==========================================================================
    // UVM Registration
    //==========================================================================
    `uvm_component_utils(axi4_rd_monitor)

    function new(string name = "axi4_rd_monitor",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //==========================================================================
    // Build Phase
    //==========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("RD_MON_CFG", "Cannot get cfg")

        if (!uvm_config_db#(virtual axi4_if.slave)::get(this, "", "vif", vif))
            `uvm_fatal("RD_MON_VIF", "Cannot get vif")

        ap_ar  = new("ap_ar", this);
        ap_rd  = new("ap_rd", this);

        mbx_ar = new();
    endfunction

    //==========================================================================
    // Run Phase
    //==========================================================================
    virtual task run_phase(uvm_phase phase);
//Vì AR và R là hai channel độc lập của AXI nên monitor cũng phải có hai thread độc lập.
        fork
            ar_thread(); //Capture Read Request.
            r_thread();
        join_none

    endtask

    //==========================================================================
    // AR Channel Monitor
    //==========================================================================
    virtual task ar_thread();

        axi4_rd_seq_item tr; 

        forever begin

            do begin
                @(posedge vif.i_clk);
            end
            while (!(vif.arvalid && vif.arready)); //đợi handshake AR

            tr = axi4_rd_seq_item::type_id::create("tr_ar");

            // Capture thông tin requesst

            tr.araddr  = vif.araddr;
            tr.arid    = vif.arid;
            tr.arlen   = vif.arlen;
            tr.arburst = vif.arburst;

            `uvm_info(get_type_name(),
                      $sformatf(
                      "AR captured: ARADDR=0x%0h ARID=0x%0h ARLEN=%0d",
                      tr.araddr,
                      tr.arid,
                      tr.arlen),
                      UVM_HIGH)

            ap_ar.write(tr); // Đã đủ thông tin read_req --> gửi đi ( Coverage) --> (INCR burst, WRAP burst, ARLEN ....)

            mbx_ar.put(tr); // Đẩy sang mail box

        end

    endtask

    //==========================================================================
    // R Channel Monitor
    //==========================================================================
    virtual task r_thread();

        axi4_rd_seq_item tr;
        int unsigned expected_beats;

        forever begin

            mbx_ar.get(tr); //Lấy request đã capture

            expected_beats = tr.arlen + 1;

            tr.rdata.delete();

            forever begin

                @(posedge vif.i_clk);

                if (!(vif.rvalid && vif.rready)) // doi handshake 
                    continue;

                tr.rdata.push_back(vif.rdata);
                tr.rresp = vif.rresp;
                tr.rid   = vif.rid;

                `uvm_info(get_type_name(),
                          $sformatf(
                          "R beat[%0d] : DATA=0x%0h LAST=%0b RESP=%0b ID=0x%0h",
                          tr.rdata.size()-1,
                          vif.rdata,
                          vif.rlast,
                          vif.rresp,
                          vif.rid),
                          UVM_HIGH)

                //----------------------------------------------------------
                // RID check
                //----------------------------------------------------------
                if (vif.rid != tr.arid) begin
                    `uvm_error(get_type_name(),
                               $sformatf(
                               "RID mismatch: RID=0x%0h ARID=0x%0h",
                               vif.rid,
                               tr.arid))
                end

                //----------------------------------------------------------
                // Early RLAST
                //----------------------------------------------------------
                if (vif.rlast &&
                    (tr.rdata.size() != expected_beats)) begin

                    `uvm_error(get_type_name(),
                               $sformatf(
                               "Early RLAST: received=%0d expected=%0d",
                               tr.rdata.size(),
                               expected_beats))
                end

                //----------------------------------------------------------
                // Last beat
                //----------------------------------------------------------
                if (vif.rlast)
                    break;

            end

            //--------------------------------------------------------------
            // Final beat count check
            //--------------------------------------------------------------
            if (tr.rdata.size() != expected_beats) begin

                `uvm_error(get_type_name(),
                           $sformatf(
                           "Beat count mismatch: received=%0d expected=%0d",
                           tr.rdata.size(),
                           expected_beats))
            end

            `uvm_info(get_type_name(),
                      $sformatf("RD captured: %s",
                                tr.convert2string()),
                      UVM_MEDIUM)

            ap_rd.write(tr); // Nếu số beat nhân dc = arlen --> okala

        end

    endtask

endclass : axi4_rd_monitor