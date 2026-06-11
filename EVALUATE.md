Những gì DUT hỗ trợ
1. Cấu trúc kênh AXI đúng kiểu
DUT có đủ 5 kênh AXI cơ bản:

AW: i_awaddr, i_awvalid, o_awready, i_awburst, i_awlen, i_awid
W: i_wdata, i_wvalid, o_wready, i_wlast
B: o_bid, o_bresp, o_bvalid, i_bready
AR: i_araddr, i_arvalid, o_arready, i_arburst, i_arlen, i_arid
R: o_rid, o_rdata, o_rresp, o_rvalid, o_rlast, i_rready
2. Burst support
Hỗ trợ INCR (2'b01), WRAP (2'b10), FIXED (2'b00)
Hỗ trợ AWLEN / ARLEN tới 255 (256 beat)
Có logic tính địa chỉ cho từng beat, bao gồm FIXED/INCR/WRAP
3. Kênh độc lập
AW và W riêng biệt, AW FIFO và W FIFO tách biệt
AR và R riêng biệt, AR FIFO và R FIFO tách biệt
4. ID giữ nguyên và phản hồi
ID được lưu từ AW/AR rồi trả về B/R đúng ID
ID width là parameterized
5. FIFO và decoupling
AW/AR/W/R/B đều có FIFO riêng
Giúp decouple handshake AXI với thời gian truy cập SRAM
m_vlsi_fifo.sv làm nhiệm vụ lưu trữ/buffer cho từng channel
Những điểm không đầy đủ so với AXI Full spec
A. Không hỗ trợ nhiều tín hiệu bắt buộc trong AXI4 full
DUT này chỉ thực hiện subset đồ họa, nó thiếu:

AWSIZE, ARSIZE
AWLEN có nhưng không có AWSIZE
AWLOCK, ARLOCK
AWCACHE, ARCACHE
AWPROT, ARPROT
AWQOS, ARQOS
AWREGION, ARREGION
AWSUSER, ARSUSER, WUSER, RUSER, BUSER
WSTRB (byte enable) hoàn toàn không có
Kết luận: đây không phải là một controller “AXI4 Full hoàn chỉnh” theo spec đầy đủ của ARM. Nó chỉ là một subset AXI4 cơ bản.

B. WLAST không được sử dụng
Port i_wlast có trong interface, nhưng trong RTL không có logic nào dùng nó.
Controller xác định kết thúc burst write bằng AWLEN/AWLAST từ AW channel, không dựa vào WLAST.
Điều này có nghĩa nếu master gửi WLAST sai thì DUT vẫn có thể xử lý theo AW length, không phải theo WLAST.
C. RRESP / BRESP cố định
o_rresp và o_bresp luôn là 2'b00 (OKAY)
DUT không tạo lỗi hoặc phản hồi lỗi
AXI full spec cho phép slave trả SLVERR/DECERR, nhưng ở đây không có
D. Byte strobes và kích thước transfer
Không có WSTRB, nên chỉ hỗ trợ transfer full-width
Không có AXSIZE, nên không xử lý size khác 32-bit
Địa chỉ tăng luôn theo PARA_DATA_WD/8, không hỗ trợ narrow hoặc variable transfer size
E. Không có các tính năng AXI nâng cao
Không có exclusive access / atomic
Không có locked transfer
Không có burst reordering / out-of-order response
Kiểm soát reorder không được xây dựng; thiết kế trả dữ liệu theo thứ tự nạp FIFO
Những điểm cụ thể cần lưu ý
1. AW/AR FIFO và handshaking
m_vlsi_axfsm tạo o_awready / o_arready khi state idle và FIFO còn chỗ
Trong m_vlsi_axfsm, beat tiếp theo chỉ đẩy khi FIFO còn chỗ
Đây là thiết kế đúng với handshake cơ bản
2. Read path
m_vlsi_sram_misc chỉ cho phép một read SRAM “in-flight” tại một thời điểm
Có thể vẫn nhận nhiều AR trước khi trả data, nhưng chỉ issue SRAM read tiếp khi lần trước đã ghi vào RFIFO
Điều này làm giảm hiệu năng với SRAM latency lớn, nhưng không nhất thiết vi phạm spec nếu hệ thống vẫn đúng về chức năng
3. Arbiter
m_vlsi_arbiter dùng round-robin giữa write và read
Đây là cơ chế hợp lý cho việc chia SRAM giữa hai đường
Tổng kết
Đây là:
một controller AXI4-like
hỗ trợ read/write burst
hỗ trợ ID, AW/AR/W/R/B channels riêng
có FIFO buffering và arbiter
Nhưng không phải “AXI4 Full spec complete”
Nó thiếu nhiều tín hiệu và tính năng quan trọng của AXI4 full:

WSTRB, AXSIZE, PROT, CACHE, LOCK, QOS, USER
không có lỗi response
WLAST input không dùng
không xử lý byte enable hoặc partial-word write