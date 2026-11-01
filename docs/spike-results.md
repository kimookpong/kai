# Phase 0 — Spike Results

โค้ด: [`spike/`](../spike) · แผน: [PLAN.md](../PLAN.md) §5 Phase 0 · งาน: [TASKS.md](../TASKS.md) P0-xx

## วิธีรัน

```bash
cd spike && swift build
B=$(swift build --show-bin-path)/KAISpike
```

ต้องให้สิทธิ์ **Camera** และ **Accessibility** แก่แอป terminal ที่ใช้รัน (System Settings → Privacy & Security)

| ทดสอบ | คำสั่ง |
| --- | --- |
| Filter (ไม่ใช้กล้อง) | `$B --selftest` |
| Latency / fps / CPU (ไม่ขยับ cursor) | `$B --dry-run --duration 20` |
| Jitter ตอนมือนิ่ง | `$B --dry-run --still-test --anchor mcp` |
| Click accuracy (เกณฑ์ Go / No-go) | `$B --click-test --anchor mcp` — 30 เป้า (24/44/64 pt) กด Esc เพื่อหยุด |
| ใช้งานจริง | `$B --anchor mcp --mode absolute` |
| เทียบ anchor | `--anchor tip`, `--anchor mcp`, `--anchor palm` |
| เทียบ mapping | `--mode absolute`, `--mode relative` |

Pinch = จีบนิ้วโป้ง+ชี้ (ratio ของระยะนิ้วต่อขนาดมือ < 0.30 กด, > 0.45 ปล่อย) ปรับได้ใน `Config.swift`

## ผลที่ยืนยันแล้ว

- One Euro Filter (`--selftest`, minCutoff 1.0, beta 0.05, 30 fps): noise ตอนนิ่ง RMS 1.67 → 0.56 px, lag ตอนกวาด 600 px/s = 0.7 px
- ยังไม่ได้วัดด้วยกล้องจริง: process ที่ใช้พัฒนาไม่มีสิทธิ์ Camera

## ตารางผลบนเครื่องจริง (ต้องกรอก)

| Anchor | Mode | Latency p50/p95 (ms) | Jitter σ raw → filtered (px) | CPU % | fps | Hit 24pt | Hit 44pt | Hit 64pt |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tip | absolute | | | | | | | |
| mcp | absolute | | | | | | | |
| palm | absolute | | | | | | | |
| mcp | relative | | | | | | | |

สภาพแวดล้อม: แสง (กลางวัน / ไฟห้อง / น้อย) · ระยะ (40 / 60 / 90 cm) · กล้อง (built-in / ภายนอก / Continuity)

## การตัดสินใจ (กรอกหลังวัด)

- Tracking provider: _Apple Vision / MediaPipe_
- Mapping mode: _absolute / relative_
- Anchor point: _tip / mcp / palm_
- Filter เริ่มต้น: minCutoff _ · beta _
- Go / No-go (click ≥ 44pt แม่น ≥ 90%): _
