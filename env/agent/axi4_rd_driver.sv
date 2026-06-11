`timescale 1ns/1ps

// =============================================================================
// axi4_rd_driver.sv
// Driver cho AXI4 Read path: AR channel + R channel (rready management)
//
// Fix so với thiết kế cũ:
//  1. Handshake hoàn toàn clock-aligned — dùng @(posedge clk) + sample flag
//  2. R channel: rready có thể deassert tạo backpressure phía read
//  3. rdata được capture trong driver (phục vụ sequences cần data ngay)
//     Monitor vẫn là nguồn chính thức cho scoreboard
//  4. Không dùng wait() ở bất kỳ đâu
// =============================================================================

class axi4_rd_driver extends uvm_driver #(axi4_rd_seq_item);

    // =========================================================================
    // Config & Interface
    // =========================================================================
    axi4_agent_cfg          cfg;
    virtual axi4_if.master  vif;

    // =========================================================================
    // UVM
    // =========================================================================
    `uvm_component_utils(axi4_rd_driver)

    function new(string name = "axi4_rd_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // =========================================================================
    // Build Phase
    // =========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4_agent_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("RD_DRV_CFG", "Cannot get cfg from config_db")
        if (!uvm_config_db#(virtual axi4_if.master)::get(this, "", "vif", vif))
            `uvm_fatal("RD_DRV_VIF", "Cannot get vif from config_db")
    endfunction

    // =========================================================================
    // Run Phase
    // =========================================================================
    virtual task run_phase(uvm_phase phase);
        reset_rd_signals();
        @(posedge vif.i_clk);

        forever begin
            axi4_rd_seq_item tr;
            seq_item_port.get_next_item(tr);

            `uvm_info(get_type_name(),
                      $sformatf("Driving: %s", tr.convert2string()),
                      UVM_MEDIUM)
// khong can fork join vi AR va R co quan he nhan qua nen la DUT chi phat R sau khi nhan AR
            drive_ar_channel(tr);
            drive_r_channel(tr);

            seq_item_port.item_done();
        end
    endtask

    // =========================================================================
    // Reset signals
    // =========================================================================
    virtual task reset_rd_signals();
        vif.master_cb.arvalid <= 1'b0;
        vif.master_cb.araddr  <= '0;
        vif.master_cb.arid    <= '0;
        vif.master_cb.arlen   <= '0;
        vif.master_cb.arburst <= 2'b01;
        vif.master_cb.rready  <= 1'b0;  // default off — driver explicit control
    endtask

    // =========================================================================
    // Drive AR channel
    // =========================================================================
    virtual task drive_ar_channel(axi4_rd_seq_item tr);
        vif.master_cb.araddr  <= tr.araddr;
        vif.master_cb.arid    <= tr.arid;
        vif.master_cb.arlen   <= tr.arlen;
        vif.master_cb.arburst <= tr.arburst;
        vif.master_cb.arvalid <= 1'b1;

        //Giu arvalid cho cho den khi arready = 1 --> handshake thanh cong --> luc nay dut da nhan Address, Burst type, ID ...

        do begin
            @(posedge vif.i_clk);
        end while (!vif.master_cb.arready);

        vif.master_cb.arvalid <= 1'b0;
        vif.master_cb.araddr  <= '0;

        `uvm_info(get_type_name(),
                  $sformatf("AR done: ARADDR=0x%0h ARID=0x%0h ARLEN=%0d",
                             tr.araddr, tr.arid, tr.arlen),
                  UVM_HIGH)
    endtask

    // =========================================================================
    // Drive R channel — assert rready, optionally deassert (backpressure)
    // Capture rdata vào tr để sequence có thể đọc (ví dụ: write-then-read check)
    // Monitor là nguồn chính cho scoreboard
    // =========================================================================

    // Theo README thi : AR handshake
                        /*      ↓
                        AXFSM tạo burst addresses
                            ↓
                        Đẩy vào ARFIFO
                            ↓
                        Arbiter chọn read
                            ↓
                        SRAM đọc dữ liệu
                            ↓
                        RFIFO chứa read response
                            ↓
                        RVALID được assert
                        */
    // Tuc la sau AR se co 1 khoang delay, kh phai gui AR xong la xuat hien du lieu ngay. 
    virtual task drive_r_channel(axi4_rd_seq_item tr);
        int unsigned expected_beats;
        expected_beats = tr.arlen + 1; // Driver biet se can nhan 4 beats
        tr.rdata.delete(); // Xoa du lieu cu neu con 

        repeat (expected_beats) begin
            int unsigned bp_cycles;

            // Backpressure phía read (đối xứng với write side) : stall rready : master chua san sang nhan du lieu
            if (cfg.backpressure_pct > 0) begin
                bp_cycles = ($urandom_range(0, 99) < cfg.backpressure_pct) ?
                            $urandom_range(1, cfg.max_backpressure_cycles) : 0;
                if (bp_cycles > 0) begin
                    vif.master_cb.rready <= 1'b0;
                    repeat (bp_cycles) @(posedge vif.i_clk);
                end
            end

            // Assert rready và chờ rvalid tại clock edge
            vif.master_cb.rready <= 1'b1;

            do begin
                @(posedge vif.i_clk);
            end while (!vif.master_cb.rvalid); // Cho DUT gui valid data 

            // Beat được accept tại posedge này — capture data
            tr.rdata.push_back(vif.master_cb.rdata);
            tr.rresp = vif.master_cb.rresp;
            tr.rid   = vif.master_cb.rid;

            `uvm_info(get_type_name(),
                      $sformatf("R  beat[%0d]: RDATA=0x%0h RLAST=%0b RRESP=%0b",
                                 tr.rdata.size()-1, vif.master_cb.rdata, vif.master_cb.rlast, vif.master_cb.rresp),
                      UVM_HIGH)

            // Kiểm tra rlast đúng vị trí
            if (vif.master_cb.rlast && (tr.rdata.size() != expected_beats))
                `uvm_error(get_type_name(),
                           $sformatf("RLAST sớm: nhận %0d beats nhưng arlen=%0d",
                                      tr.rdata.size(), tr.arlen))
        end

        vif.master_cb.rready <= 1'b0;

        `uvm_info(get_type_name(),
                  $sformatf("R  done: RID=0x%0h BEATS=%0d RRESP=%0b",
                             tr.rid, tr.rdata.size(), tr.rresp),
                  UVM_MEDIUM)
    endtask

    /*
                                    Driver gửi AR
                                            ↓
                                    AR handshake
                                            ↓
                                    DUT đọc SRAM
                                            ↓
                                    R beat0
                                            ↓
                                    R beat1
                                            ↓
                                    R beat2
                                            ↓
                                    R beat3 + RLAST
                                            ↓
                                    R channel hoàn tất
                                            ↓
                                    item_done()
*/

endclass : axi4_rd_driver