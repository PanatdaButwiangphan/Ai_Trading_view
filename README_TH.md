# AiTradingView — EA สำหรับ Exness MT5 (v1.61)

> Copy + Compile จนหัวข้อขึ้น **`AiTradingView 1.61`**

## ของใหม่ใน v1.61

| ฟีเจอร์ | รายละเอียด |
|--------|------------|
| Trade permission | เช็ค `TERMINAL_TRADE_ALLOWED` / `ACCOUNT_TRADE_ALLOWED` / `MQL_TRADE_ALLOWED` ก่อนส่งออร์เดอร์และ retry |
| Panel Algo + Block | โชว์ `Algo: ON/OFF (...)` และ `Block: ...` ว่าทำไมยังไม่เข้าไม้ (อัปเดตทุก tick) |
| CSV Journal | ปิดไม้ magic ของ EA แล้ว append ลง `AITV_journal.csv` (Common\Files) |
| เว็บ Journal | เปิด [`web/journal.html`](web/journal.html) → อัปโหลด/ลาก CSV ดูตาราง + win rate + net PnL + **สรุปรายวันอัตโนมัติ** |

## SL / TP อัตโนมัติ (มีอยู่แล้ว)

- ออโต้: ใส่ SL/TP ตอน `Buy`/`Sell` ทันที
- ออเดอร์มือ: เปิด `InpManageManualOrders` แล้ว EA จะ `PositionModify` ใส่ SL/TP ให้ถ้ายังว่าง

## ของที่คงจาก v1.60

Retry re-guards, `InpMaxAccountEaPositions`, calendar day/week/month keys, log `attempt k/N (initial|retry)`

## วิธีใช้

1. ชาร์ต **M1** → ลาก EA  
2. เปิด **Algo Trading** (ปุ่มมุมขวาบน) — แผงต้องขึ้น `Algo: ON`  
3. ดูบรรทัด `Block:` ถ้ายังไม่เข้าไม้  
4. ออเดอร์มือยังใส่ SL/TP ได้  

## Journal

1. ใน EA เปิด `InpJournalCsv` (ค่าเริ่มต้น ON)  
2. หลังปิดไม้ → ไฟล์อยู่ที่ **Data Folder → `Common\Files\AITV_journal.csv`**  
3. เปิดในเครื่อง: `web/journal.html` หรือ `web/index.html` → ลากไฟล์ CSV มาวาง  
4. หน้าเว็บจะสรุปให้อัตโนมัติ: **Today** + ตาราง **Daily summary** (วันที่ / จำนวนไม้ / win% / net PnL) + รายไม้ทั้งหมด  
   ไม่ต้องพิมพ์สรุปรายวันเอง — รวมจากคอลัมน์ `time` ใน CSV

### Deploy ขึ้น Vercel

1. Push โปรเจกต์ขึ้น GitHub  
2. [Vercel](https://vercel.com) → New Project → Import repo  
3. ตั้ง **Root Directory = `web`** (มี `index.html` + `vercel.json`) → Deploy  
4. เปิด URL แล้ว**ลาก/อัปโหลด `AITV_journal.csv` เอง** — เว็บบน Vercel อ่านโฟลเดอร์ MT5 จากเครื่องคุณอัตโนมัติไม่ได้  

หมายเหตุ: แก้ journal แล้วควรอัปเดตทั้ง `web/index.html` และ `web/journal.html` ให้ตรงกัน (หรือ copy ทับกัน) ก่อน deploy รอบถัดไป

## ติดตั้ง

1. MetaEditor → Data Folder → `MQL5\Experts\`  
2. ทับ `AiTradingView.mq5` → Compile (F7)  
3. ถอด EA เก่า → ลากใหม่ → ตรวจ **1.61**

## Inputs เพิ่ม (v1.61)

- `InpJournalCsv` — เขียน journal CSV เมื่อปิดไม้ magic ของ EA

## คำเตือน

การเทรดมีความเสี่ยงสูง โดยเฉพาะ M1  
ไม่รับประกันกำไร
