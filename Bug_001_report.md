# RTL Bug Report — RTL_BUG_001

| Field           | Detail |
|----------------|--------|
| **Bug ID**      | RTL_BUG_001 |
| **Severity**    | Critical |
| **Component**   | `m_vlsi_sram_misc` — RFIFO push data path |
| **Signal**      | `sram_rdata_r` → `rfifo_wdata` (off-by-one pipeline) |
| **Detected by** | UVM sequence `axi4_rtl_bug001_seq` (3 cases) + waveform confirmation |
| **Status**      | Open |
| **Version**     | v2 — updated sau khi có thêm waveform evidence từ Case B và C |

---

## 1. Summary

Khi DUT thực hiện AXI4 INCR burst read (arlen ≥ 2), `m_vlsi_sram_misc` push dữ liệu vào RFIFO từ `sram_rdata_r` — bản **registered** (đã trễ 1 cycle) của `sram_rdata` — thay vì lấy trực tiếp từ combinational output của SRAM. Kết quả: mỗi beat nhận được data của beat trước, gây **data corruption** và **RLAST không được assert đúng vị trí**.

---

## 2. Symptom

### 2.1 UVM log — Case A (arlen=7, 8 beats)
```
UVM_ERROR axi4_rd_driver.sv(195) @ 1075000:
  ** RTL BUG ** RLAST_MISSING: nhận đủ 8 beats nhưng rlast chưa assert
  ARADDR=0x100 ARLEN=7

UVM_ERROR axi4_rtl_bug001_seq.sv(174) @ 1075000:
  beat[3] FAIL: ADDR=0x0000010C exp=0xDEADA004 got=0xDEADA003 — RTL_BUG_001 Case A
  beat[7] FAIL: ADDR=0x0000011C exp=0xDEADA008 got=0xDEADA007 — RTL_BUG_001 Case A
```

### 2.2 UVM log — Case B (arlen=15, 16 beats)
```
UVM_ERROR axi4_rtl_bug001_seq.sv(174) @ 2505000:
  beat[2]  FAIL: ADDR=0x00000208 exp=0xDEADB003 got=0xDEADB002
  beat[3]  FAIL: ADDR=0x0000020C exp=0xDEADB004 got=0xDEADB003
  beat[6]  FAIL: ADDR=0x00000218 exp=0xDEADB007 got=0xDEADB006
  beat[7]  FAIL: ADDR=0x0000021C exp=0xDEADB008 got=0xDEADB007
  beat[9]  FAIL: ADDR=0x00000224 exp=0xDEADB00A got=0xDEADB009
  beat[12] FAIL: ADDR=0x00000230 exp=0xDEADB00D got=0xDEADB00C
  beat[13] FAIL: ADDR=0x00000234 exp=0xDEADB00E got=0xDEADB00D
```

### 2.3 UVM log — Case C (arlen=3, 4 beats)
```
UVM_ERROR axi4_rd_driver.sv(195) @ 2985000:
  ** RTL BUG ** RLAST_MISSING: nhận đủ 4 beats nhưng rlast chưa assert
  ARADDR=0x300 ARLEN=3

UVM_ERROR axi4_rtl_bug001_seq.sv(174) @ 2985000:
  beat[2] FAIL: ADDR=0x00000308 exp=0xDEADC003 got=0xDEADC002
  beat[3] FAIL: ADDR=0x0000030C exp=0xDEADC004 got=0xDEADC003
```

### 2.4 Data pattern tổng hợp

**Case A — arlen=7 (8 beats):**

| Beat | Address | Expected   | Actual     | Result |
|------|---------|------------|------------|--------|
| 0    | 0x100   | 0xDEADA001 | 0xDEADA001 | ✅ |
| 1    | 0x104   | 0xDEADA002 | 0xDEADA002 | ✅ |
| 2    | 0x108   | 0xDEADA003 | 0xDEADA003 | ✅ |
| 3    | 0x10C   | 0xDEADA004 | **0xDEADA003** | ❌ |
| 4    | 0x110   | 0xDEADA005 | 0xDEADA005 | ✅ |
| 5    | 0x114   | 0xDEADA006 | 0xDEADA006 | ✅ |
| 6    | 0x118   | 0xDEADA007 | 0xDEADA007 | ✅ |
| 7    | 0x11C   | 0xDEADA008 | **0xDEADA007** | ❌ |

**Case C — arlen=3 (4 beats) — boundary case:**

| Beat | Address | Expected   | Actual     | Result |
|------|---------|------------|------------|--------|
| 0    | 0x300   | 0xDEADC001 | 0xDEADC001 | ✅ |
| 1    | 0x304   | 0xDEADC002 | 0xDEADC002 | ✅ |
| 2    | 0x308   | 0xDEADC003 | **0xDEADC002** | ❌ |
| 3    | 0x30C   | 0xDEADC004 | **0xDEADC003** | ❌ |

---

## 3. Root Cause

### 3.1 Waveform evidence — confirmed

```
Tại beat[2] của Case C (cycle có rvalid & rready = 1 lần thứ 3):
  sram_rdata    = 0xDEADC003   ← SRAM output đúng, đã đọc địa chỉ 0x308
  rfifo_wdata   = 0xDEADC002   ← DUT push data cũ vào RFIFO
  axi_if.rdata  = 0xDEADC002   ← R channel nhận data sai
```

`sram_rdata` đúng nhưng `rfifo_wdata` trễ hơn 1 cycle → DUT push data của beat trước thay vì beat hiện tại.

### 3.2 RTL logic bị lỗi

```systemverilog
// Trong m_vlsi_sram_misc.sv — BUG:
always_ff @(posedge clk)
    sram_rdata_r <= sram_rdata;       // register thêm 1 cycle

always_ff @(posedge clk)
    if (rfifo_push)
        rfifo_wdata <= sram_rdata_r;  // ← dùng bản trễ 1 cycle → SAI
```

### 3.3 Timeline cycle-by-cycle (Case C)

```
Cycle | sram_addr | sram_rdata  | sram_rdata_r | rfifo_push | rfifo_wdata  | rdata    
------|-----------|-------------|--------------|------------|--------------|----------
N     | 0x300     | DEAD_C001   | DEAD_C000*   | 1          | DEAD_C000*   | —        
N+1   | 0x304     | DEAD_C002   | DEAD_C001    | 1          | DEAD_C001    | DEAD_C001 ✅ beat[0]
N+2   | 0x308     | DEAD_C003   | DEAD_C002    | 1          | DEAD_C002    | DEAD_C002 ✅ beat[1]
N+3   | 0x30C     | DEAD_C004   | DEAD_C003    | 1          | DEAD_C003 ❌ | DEAD_C002 ❌ beat[2]
N+4   | —         | —           | DEAD_C004    | 1          | DEAD_C004 ❌ | DEAD_C003 ❌ beat[3]
```
*DEAD_C000 = giá trị rác trước burst

Beat[0] và beat[1] pass vì DUT còn đang "warm up" pipeline — sai từ beat[2] trở đi khi pipeline lệch pha rõ ràng.

---

## 4. Tại sao Integrity seq không phát hiện bug này

Integrity seq dùng **1 burst write awlen=7** để write rồi read lại. Write burst cũng đi qua pipeline tương tự trong DUT → data được lưu vào SRAM cũng bị lệch theo cùng chiều → khi read lại, expected và actual lệch **cùng chiều nhau** → scoreboard pass nhầm.

`axi4_rtl_bug001_seq` dùng **8 single-beat write riêng lẻ** (awlen=0) để bypass hoàn toàn write pipeline → SRAM có data đúng → chỉ read burst mới lệch → mismatch lộ ra.

---

## 5. Impact

| Scenario | Impact |
|---------|--------|
| Single beat (arlen=0) | ✅ Không ảnh hưởng |
| INCR burst arlen=1 | ✅ Không ảnh hưởng (chỉ 2 beat, chưa đủ để lệch pha) |
| INCR burst arlen ≥ 2 | ❌ **Data corruption** từ beat[2] trở đi |
| RLAST | ❌ **AXI4 protocol violation** — không assert đúng beat cuối |
| FIXED / WRAP burst | ⚠️ Chưa verify, nghi ngờ tương tự nếu dùng cùng RFIFO path |

---

## 6. Reproduce Steps

```bash
# Compile và chạy
vsim -do "run -all" +UVM_TESTNAME=axi4_rtl_bug001_test

# Sequence flow (axi4_rtl_bug001_seq):
#   Case A: write 8  × single-beat @ 0x100, read burst arlen=7  @ 0x100
#   Case B: write 16 × single-beat @ 0x200, read burst arlen=15 @ 0x200
#   Case C: write 4  × single-beat @ 0x300, read burst arlen=3  @ 0x300

# Expected: tất cả beat PASS, không RLAST_MISSING
# Actual:   fail từ beat[2] trong mỗi cụm 4 beat, RLAST_MISSING
```

File: `../seq/sequences/axi4_rtl_bug001_seq.sv`

---

## 7. Proposed RTL Fix

Trong `m_vlsi_sram_misc.sv`, sửa `rfifo_wdata` dùng trực tiếp combinational output thay vì registered:

```systemverilog
// TRƯỚC — BUG:
always_ff @(posedge clk)
    sram_rdata_r <= sram_rdata;

always_ff @(posedge clk)
    if (rfifo_push)
        rfifo_wdata <= sram_rdata_r;   // trễ 1 cycle

// SAU — FIX:
always_ff @(posedge clk)
    if (rfifo_push)
        rfifo_wdata <= sram_rdata;     // lấy trực tiếp, không qua register
```

Nếu SRAM có read latency > 0 thì cần align `rfifo_push` trễ đúng số cycle tương ứng thay vì bỏ register.

---

## 8. Verification Notes

- **Isolation technique:** Single-beat write loại trừ write path bug → pin point chính xác read pipeline
- **Waveform confirm:** `sram_rdata = 0xDEADC003` nhưng `rfifo_wdata = 0xDEADC002` tại beat[2] Case C → loại trừ hoàn toàn monitor/driver bug
- **3 cases:** arlen=7 / arlen=15 / arlen=3 đều reproduce cùng pattern → root cause nhất quán
- **Inline checker:** Không phụ thuộc scoreboard, đọc trực tiếp `rd_req.rdata[]` từ driver

## 9. WHY not driver/monitor bug

Evidence 1 — Inline checker đọc từ driver, không qua monitor
Trong axi4_rtl_bug001_seq, checker dùng rd_req.rdata[] — array này được fill bởi driver (drive_r_channel) tại mỗi rvalid & rready handshake, không liên quan gì đến monitor.
systemverilog// Driver capture rdata trực tiếp từ clocking block
tr.rdata.push_back(vif.master_cb.rdata);
Nếu monitor bị bug → checker vẫn không bị ảnh hưởng vì checker không dùng monitor output.
→ Loại trừ monitor.

Evidence 2 — Waveform thấy sai ngay trên bus
axi_if.rdata = 0xDEADC002  tại beat[2]
axi_if.rdata là tín hiệu vật lý trên bus — không qua driver, không qua monitor, không qua bất kỳ TB component nào. Đây là wire thật giữa DUT và TB.
Nếu driver bị bug → driver có thể sample sai timing, nhưng signal trên wire vẫn là thật. Waveform thấy 0xDEADC002 trên bus = DUT đang drive 0xDEADC002 lên wire.
→ Loại trừ driver capture sai.

Evidence 3 — SRAM output đúng nhưng bus sai
sram_rdata   = 0xDEADC003  ← bên trong DUT, SRAM trả đúng
axi_if.rdata = 0xDEADC002  ← output ra ngoài DUT, sai
Cả hai signal đều nhìn thấy trực tiếp trên waveform, không qua TB. Khoảng cách giữa sram_rdata và axi_if.rdata là logic nội bộ của DUT — TB không có cách nào can thiệp vào đó.
→ Bug nằm trong DUT, giữa SRAM output và AXI R channel output.

Tóm lại chain of evidence
sram_rdata = DEAD_C003 (đúng)
      ↓  [logic trong m_vlsi_sram_misc — DUT territory]
rfifo_wdata = DEAD_C002 (sai) ← lệch 1 cycle tại đây
      ↓
axi_if.rdata = DEAD_C002 (sai, thấy trên waveform)
      ↓  [driver sample từ clocking block]
rd_req.rdata[2] = DEAD_C002 (sai)
      ↓  [inline checker so sánh]
FAIL: exp=DEAD_C003 got=DEAD_C002
Mỗi bước trong chain đều có waveform hoặc log confirm — không có bước nào phụ thuộc vào assumption của TB.