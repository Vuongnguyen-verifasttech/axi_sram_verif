`timescale 1ns/1ps

//==============================================================================
// File          : axi4_wr_monitor.sv
// Description   : AXI4 Write Monitor
//
// DUT assumptions:
//   - No out-of-order response
//   - No write reordering
//   - Single write transaction flow
//   - WLAST không phải source of truth
//   - AWLEN quyết định số beat thực tế
//
// Capture flow:
//   AW handshake
//      ↓
//   Capture AW fields
//      ↓
//   Capture (AWLEN+1) W beats
//      ↓
//   Capture B response
//      ↓
//   ap_wr.write()
//
// Notes:
//   - Phù hợp với DUT hiện tại
//   - Dễ debug
//   - Không cần mailbox assembly phức tạp
//==============================================================================

class axi4_wr_monitor extends uvm_monitor;

    //----------------------------------------------------------------------
    // Config & Interface
    //----------------------------------------------------------------------
    axi4_agent_cfg         cfg;
    virtual axi4_if.slave  vif;

    //----------------------------------------------------------------------
    // Analysis Ports
    //----------------------------------------------------------------------
    uvm_analysis_port #(axi4_wr_seq_item) ap_wr;
    uvm_analysis_port #(axi4_wr_seq_item) ap_aw;

    //----------------------------------------------------------------------
    // UVM
    //----------------------------------------------------------------------
    `uvm_component_utils(axi4_wr_monitor)

    function new(string name = "axi4_wr_monitor",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //----------------------------------------------------------------------
    // Build
    //----------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(axi4_agent_cfg)::get(this,"","cfg",cfg))
            `uvm_fatal("WR_MON_CFG","Cannot get cfg")

        if (!uvm_config_db#(virtual axi4_if.slave)::get(this,"","vif",vif))
            `uvm_fatal("WR_MON_VIF","Cannot get vif")

        ap_wr = new("ap_wr", this);
        ap_aw = new("ap_aw", this);
    endfunction

    //----------------------------------------------------------------------
    // Run
    //----------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);

        forever begin

            axi4_wr_seq_item tr;
            int unsigned num_beats;

            tr = axi4_wr_seq_item::type_id::create("tr");

            //------------------------------------------------------------------
            // AW Channel
            //------------------------------------------------------------------
            @(vif.slave_cb iff (vif.slave_cb.awvalid && vif.slave_cb.awready));
                `uvm_info("MON_AW",
                $sformatf(
                "@%0t AW handshake awid=%0h awaddr=%0h",
                $time,
                vif.slave_cb.awid,
                vif.slave_cb.awaddr),
                UVM_NONE)

            // Handshake thanh cong, capture lại transaction: awaddr, awid, awlen, awburst

            tr.awaddr  = vif.slave_cb.awaddr;
            tr.awid    = vif.slave_cb.awid;
            tr.awlen   = vif.slave_cb.awlen;
            tr.awburst = vif.slave_cb.awburst;

            num_beats = tr.awlen + 1; // tinh lai so beats to capture chinh xac 
            

            `uvm_info(get_type_name(),
                      $sformatf(
                        "AW captured: AWADDR=0x%0h AWID=0x%0h AWLEN=%0d",
                        tr.awaddr,
                        tr.awid,
                        tr.awlen),
                      UVM_HIGH)

            ap_aw.write(tr);

            //------------------------------------------------------------------
            // W Channel
            //------------------------------------------------------------------
            tr.wdata.delete();

            repeat(num_beats) begin

                            do begin
                @(vif.slave_cb);
                end while (!(vif.slave_cb.wvalid &&
                            vif.slave_cb.wready));

                tr.wdata.push_back(vif.slave_cb.wdata); // capture 

                `uvm_info(get_type_name(),
                          $sformatf(
                            "W beat[%0d]: WDATA=0x%0h",
                            tr.wdata.size()-1,
                            vif.slave_cb.wdata),
                          UVM_HIGH)
            end

            //------------------------------------------------------------------
            // B Channel
            //------------------------------------------------------------------
                    do begin
            @(vif.slave_cb);
        end while (!(vif.slave_cb.bvalid &&
                    vif.slave_cb.bready));
                            `uvm_info("MON_B",
            $sformatf(
            "@%0t bvalid=%0b bready=%0b bid=%0h",
            $time,
            vif.slave_cb.bvalid,
            vif.slave_cb.bready,
            vif.slave_cb.bid),
            UVM_NONE)

            tr.bresp = vif.slave_cb.bresp; // capture response 
            tr.bid   = vif.slave_cb.bid;

            `uvm_info(get_type_name(),
                      $sformatf(
                        "B captured: BID=0x%0h BRESP=%0b",
                        tr.bid,
                        tr.bresp),
                      UVM_HIGH)

            //------------------------------------------------------------------
            // Sanity checks
            //------------------------------------------------------------------
            if (tr.wdata.size() != (tr.awlen + 1))
                `uvm_error(get_type_name(),
                           $sformatf(
                             "Beat mismatch: got=%0d expected=%0d",
                             tr.wdata.size(),
                             tr.awlen + 1))

            //------------------------------------------------------------------
            // Send to scoreboard
            //------------------------------------------------------------------
            `uvm_info(get_type_name(),
                      $sformatf("WRITE captured: %s",
                                tr.convert2string()),
                      UVM_MEDIUM)

            ap_wr.write(tr); // du thong tin ve transaction --> gui scoreboard

        end

    endtask

endclass