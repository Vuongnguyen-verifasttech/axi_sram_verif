//==============================================================================
// File          : axi4_driver.sv
// Author        : [vnguyen-kafka]
// Company       : [Verifast]
// Project       : AXI4 SRAM Verification Environment
// Description   : UVM Driver for AXI4 Master
//                 - Fetches transactions from Sequencer
//                 - Drives AXI4 signals via clocking block safely
//
// Version       : 1.0 (Fixed from interface clone)
// Date          : 01-June-2026
//==============================================================================

class axi4_driver extends uvm_driver #(axi4_transaction);

  `uvm_component_utils(axi4_driver)

  // Virtual interface kết nối với Modport Driver
  virtual axi4_if.driver vif;

  // =====================================================================
  // Constructor
  // =====================================================================
  function new(string name = "axi4_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // =====================================================================
  // Build Phase: Lấy Virtual Interface từ Config DB
  // =====================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_if.driver)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface (vif) not found in config_db!")
    end
  endfunction

  // =====================================================================
  // Run Phase: Luồng xử lý chính của Driver
  // =====================================================================
  virtual task run_phase(uvm_phase phase);
    reset_signals();
    
    forever begin
      // Chờ cho đến khi rst_n giải phóng (active high trong logic kiểm tra)
      wait(vif.i_rst_n == 1'b1);
      
      seq_item_port.get_next_item(req);
      
      if (req.is_write) begin
        drive_write(req);
      end else begin
        drive_read(req);
      end
      
      seq_item_port.item_done();
    end
  endtask

  // =====================================================================
  // Khởi tạo trạng thái ban đầu cho các Output của Master
  // =====================================================================
  virtual task reset_signals();
    vif.cb_driver.awvalid <= 1'b0;
    vif.cb_driver.wvalid  <= 1'b0;
    vif.cb_driver.wlast   <= 1'b0;
    vif.cb_driver.bready  <= 1'b0;
    vif.cb_driver.arvalid <= 1'b0;
    vif.cb_driver.rready  <= 1'b0;
  endtask

  // =====================================================================
  // Xử lý chu kỳ Ghi chuẩn (AW + W -> B)
  // =====================================================================
  virtual task drive_write(axi4_transaction tr);
    // 1. Khởi tạo Kênh Địa chỉ Ghi (AW)
    vif.cb_driver.awaddr  <= tr.axaddr;
    vif.cb_driver.awlen   <= tr.axlen;
    vif.cb_driver.awburst <= tr.axburst;
    vif.cb_driver.awid    <= tr.axid;
    vif.cb_driver.awvalid <= 1'b1;

    // 2. Khởi tạo Kênh Dữ liệu Ghi (W) - Beat đầu tiên
    vif.cb_driver.wdata   <= tr.data[0];
    vif.cb_driver.wlast   <= (tr.axlen == 0);
    vif.cb_driver.wvalid  <= 1'b1;

    fork
      // Luồng xử lý bắt tay kênh AW
      begin
        @(vif.cb_driver);
        while (!vif.cb_driver.awready) begin
          @(vif.cb_driver);
        end
        vif.cb_driver.awvalid <= 1'b0;
      end

      // Luồng xử lý đẩy toàn bộ các beat dữ liệu kênh W
      begin
        for (int i = 0; i <= tr.axlen; i++) begin
          if (i > 0) begin // Đưa dữ liệu các beat tiếp theo (nếu có)
            vif.cb_driver.wdata  <= tr.data[i];
            vif.cb_driver.wlast  <= (i == tr.axlen);
            vif.cb_driver.wvalid <= 1'b1;
          end
          
          @(vif.cb_driver);
          while (!vif.cb_driver.wready) begin
            @(vif.cb_driver);
          end
        end
        vif.cb_driver.wvalid <= 1'b0;
        vif.cb_driver.wlast  <= 1'b0;
      end
    join

    // 3. Chờ phản hồi từ Kênh Phản hồi Ghi (B)
    vif.cb_driver.bready <= 1'b1;
    @(vif.cb_driver);
    while (!vif.cb_driver.bvalid) begin
      @(vif.cb_driver);
    end
    vif.cb_driver.bready <= 1'b0;
  endtask

  // =====================================================================
  // Xử lý chu kỳ Đọc chuẩn (AR -> R)
  // =====================================================================
  virtual task drive_read(axi4_transaction tr);
    // 1. Gửi thông tin yêu cầu đọc lên kênh AR
    vif.cb_driver.araddr  <= tr.axaddr;
    vif.cb_driver.arlen   <= tr.axlen;
    vif.cb_driver.arburst <= tr.axburst;
    vif.cb_driver.arid    <= tr.axid;
    vif.cb_driver.arvalid <= 1'b1;

    @(vif.cb_driver);
    while (!vif.cb_driver.arready) begin
      @(vif.cb_driver);
    end
    vif.cb_driver.arvalid <= 1'b0;

    // 2. Sẵn sàng nhận dữ liệu trả về từ kênh R
    vif.cb_driver.rready <= 1'b1;
    for (int i = 0; i <= tr.axlen; i++) begin
      @(vif.cb_driver);
      while (!vif.cb_driver.rvalid) begin
        @(vif.cb_driver);
      end
      // Monitor sẽ làm nhiệm vụ thu thập mảng rdata, driver chỉ giữ rready đúng giao thức
    end
    vif.cb_driver.rready <= 1'b0;
  endtask

endclass : axi4_driver