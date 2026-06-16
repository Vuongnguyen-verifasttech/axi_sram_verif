1. Divide logic driver/ monitor to 5 channels
2. Verify inside not only verify DUT
3. Config nên config ở lớp test

4. ENV trace burst bằng awlen do cái awlast luôn  = 1

//================================================
BUG 1: 
Sram model ban đầu: 
assign sram_rdata =
    (sram_oe) ? sram_mem[sram_addr[11:2]] : 32'h0;
--> khi sram_oe = 1 --> data xuat ngay lap tức

Tuy nhiên trong dut: 
assign o_sram_oe = w_rd_issue;
assign o_rfifo_push = reg_rd_pending;

và 
always_ff @(posedge clk)
    reg_rd_pending <= w_rd_issue;

--> o_rfifo_push trễ 1 cycle so với o_sram_oe

FLOW thực tế
    - Cycle n : 
        w_rd_issue = 1
        o_sram_oe  = 1
    Sram trả: 
        i_sram_rdata = e0715b4d
    nhưng: 
        o_rfifo_push = 0 
    --> data chưa dc push
    - Cycle n+1:
        o_rfifo_push = 1 
    Nhưng lúc này: 
        o_sram_oe = 0
    Nên tb sẽ trả: 
        i_sram_rdata = 0
    --> Lúc này RFIFO ghi vào giá trị 0 
==> Dẫn đến toàn bộ giá trị được đọc ra đều = 0. 
SOLUTION: 
Đổi SRAM thành synchronous: 
always_ff @(posedge clk)
begin
    if (sram_oe)
        sram_rdata <= sram_mem[sram_addr[11:2]];
end

do: SRAM latency = 1 cycle
Vì RTL của DUT vốn được viết theo giả định:
Issue read
    ↓
đợi 1 cycle
    ↓
data từ SRAM xuất hiện
    ↓
push vào RFIFO

Nhưng testbench ban đầu của  lại mô phỏng:

SRAM latency = 0 cycle

==> timing bị lệch 1 cycle. 
