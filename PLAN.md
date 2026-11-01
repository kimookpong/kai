# KAI — Development Plan

> อ้างอิง: [CONCEPT.md](CONCEPT.md) · รายการงาน: [TASKS.md](TASKS.md)

เอกสารนี้แปลง concept ให้เป็นแผนที่ลงมือทำได้จริง โดยปรับ roadmap จาก CONCEPT.md ตามผลการวิเคราะห์:
ทดสอบสมมติฐานที่เสี่ยงที่สุดก่อน, ดึง Voice + AI ขึ้นมาเร็วขึ้น, และวาง **Point + Speak** เป็นจุดขายหลัก

---

## 1. Positioning

### 1.1 Differentiator

KAI ไม่ได้แข่งเป็น "finger mouse" และไม่ได้แข่งเป็น "AI agent อีกตัว"

จุดที่ KAI แตกต่างคือ **การรวม gesture กับ voice ให้เป็นคำสั่งเดียว (deictic interaction)**:

```text
👉 (ชี้ไฟล์)      "KAI, ส่งอันนี้ให้ทีม"
👉 (ชี้หน้าต่าง)   "ย้ายอันนี้ไปจอขวา"
👉 (ชี้ error)    "อันนี้คืออะไร แก้ให้หน่อย"
```

Gesture ทำหน้าที่ **ให้ context กับ AI** ไม่ใช่แค่แทนเมาส์

### 1.2 Target users (เรียงตามลำดับความสำคัญ)

1. **Developers / power users บน Mac** — ใช้ voice + agent + point เพื่อสั่งงานเร็วขึ้น
2. **Presenters** — ควบคุมสไลด์/หน้าจอจากระยะไกล
3. **ผู้ที่มีข้อจำกัดในการใช้เมาส์/คีย์บอร์ด** — กลุ่มที่ gesture มีคุณค่าสูงสุด (ต้องออกแบบ accessibility ให้ดี)

### 1.3 Non-goals (สำหรับ v1)

- ไม่พยายามแทนที่ trackpad/เมาส์ทั้งหมดสำหรับการใช้งานต่อเนื่องหลายชั่วโมง
- ไม่สร้าง LLM / coding model เอง
- ไม่รองรับ Windows / Linux
- ไม่ขึ้น Mac App Store (ต้องใช้ Accessibility + CGEvent นอก sandbox → แจกผ่าน Developer ID + notarization)
- ไม่ทำ smart home / iPhone / Vision Pro ใน v1

---

## 2. Guiding Principles

| หลักการ | ความหมายในทางปฏิบัติ |
| --- | --- |
| **Validate first** | ทุก phase ที่มีความเสี่ยงด้านเทคนิคเริ่มด้วย spike ที่มีตัวเลขวัดผล |
| **Fast path / Slow path** | งาน real-time (cursor) แยกจากงาน AI โดยเด็ดขาด |
| **Explicit engagement** | ระบบไม่ตีความการขยับมือ/เสียงเป็นคำสั่ง จนกว่าผู้ใช้จะ "เปิดใช้" ชัดเจน (clutch) |
| **Local first** | Hand tracking, wake word, STT พยายามทำบนเครื่อง |
| **Policy before execution** | LLM ไม่เคยเรียก macOS ตรง ๆ ทุกอย่างผ่าน Tool → Policy → Confirmation → Executor |
| **Standards over custom** | ใช้ MCP สำหรับ tool system แทนการออกแบบ protocol เอง |
| **Replaceable providers** | Tracking, STT, TTS, LLM ทุกตัวอยู่หลัง protocol |

---

## 3. Architecture

### 3.1 Two execution paths

```text
FAST PATH  (target < 16ms ต่อเฟรม, ไม่ผ่าน main thread)
Camera → HandTracking → Filter → GestureStateMachine → ActionMapper → CGEvent

SLOW PATH  (วินาที, async)
Voice / Gesture / Text
      ↓
InputFusion (รวม "ชี้อะไร" + "พูดอะไร")
      ↓
Intent → LLM (tool calling) → Planner
      ↓
Tool Request → Policy Engine → Confirmation UI → Tool Executor → macOS / MCP
      ↓
Observation → Audit Log → Response (TTS / HUD)
```

### 3.2 Modules (Xcode app + local Swift packages)

แยกเป็น package เพื่อให้ test ได้โดยไม่ต้องรันแอป และบังคับ dependency direction

```text
KAI.xcodeproj               ← App target (menu bar, UI, permissions prompts)
Packages/
├── KAICore                 ← Events (typed AsyncStream), Config, Logging, Permissions model
├── KAITracking             ← HandTrackingProvider protocol, AppleVisionTracker, MediaPipeTracker
├── KAIGesture              ← Filters (One Euro), GestureStateMachine, Recognizers, ActionMapper
├── KAIActions              ← Mouse, Keyboard, Window, Volume, Brightness, Media controllers
├── KAIContext              ← ActiveApplication, AX element-at-point, AppProfiles
├── KAIVoice                ← SpeechToTextProvider, TextToSpeechProvider, WakeWordProvider
├── KAIAgent                ← LLMProvider, ToolRegistry, PolicyEngine, Planner loop, AuditLog
└── KAIMCP                  ← MCP client (ใช้ tool ภายนอก) + MCP server (เปิด tool ของ KAI)
```

Dependency direction: `App → Agent/Voice/Gesture → Actions/Context/Tracking → Core`

### 3.3 Naming fixes จาก CONCEPT.md

- `Vision/VisionProvider.swift` → `HandTrackingProvider`
- `AI/VisionProvider.swift` → `VisionModelProvider` (vision LLM สำหรับเข้าใจหน้าจอ)
- EventBus → typed `AsyncStream<KAIEvent>` แทน NotificationCenter

---

## 4. Key Technical Decisions

| เรื่อง | ตัดสินใจ | สถานะ |
| --- | --- | --- |
| ภาษา / UI | Swift 6 + SwiftUI, AppKit เมื่อจำเป็น | ✅ Decided |
| Minimum macOS | macOS 14 (Sonoma) | ✅ Decided |
| Distribution | Developer ID + notarization, ไม่ sandbox | ✅ Decided |
| Hand tracking | Apple Vision vs MediaPipe | ⏳ ตัดสินหลัง Spike (P0) |
| Cursor filter | One Euro Filter | ✅ Decided |
| Cursor mapping | Absolute vs Relative (trackpad-like) | ⏳ ตัดสินหลัง Spike |
| Cursor anchor | โคนนิ้วชี้ / กลางฝ่ามือ (ไม่ใช่ปลายนิ้ว เพราะกระโดดตอน pinch) | ⏳ ยืนยันใน Spike |
| Engagement | Clutch gesture + global hotkey | ✅ Decided |
| STT | Apple Speech on-device ก่อน, สำรอง whisper.cpp | ⏳ ทดสอบภาษาไทย + ไทยปนอังกฤษ |
| Wake word | **ไม่ใช้ "ไค" คำเดียว** (ชนกับ ไก่ / ไข่) — ใช้ "Hey KAI" หรือ push-to-talk | ✅ Decided (เลื่อนไป Phase 5) |
| LLM | Provider protocol, เริ่มด้วย Anthropic API + รองรับ local (Ollama) | ✅ Decided |
| Tool protocol | MCP | ✅ Decided |
| UI automation order | API/CLI → AppleScript/Shortcuts → AX tree → Screenshot + vision | ✅ Decided |

---

## 5. Roadmap

ระยะเวลาเป็นค่าประมาณสำหรับนักพัฒนา 1 คน (part-time ให้คูณประมาณ ×2)

### Phase 0 — Feasibility Spike (2 สัปดาห์)

**เป้าหมาย:** ตอบให้ได้ว่า gesture-based cursor บน webcam ของ Mac "ใช้ได้จริง" แค่ไหน ก่อนลงทุนต่อ

- Prototype เล็กที่สุด: กล้อง → hand landmarks → cursor
- เทียบ Apple Vision กับ MediaPipe ด้วยตัวเลขจริง
- ทดสอบ anchor point, filter, absolute vs relative

**Exit criteria:**
- มีตารางผล: latency (end-to-end), jitter (px ตอนมือนิ่ง), CPU %, fps, ความแม่นของ pinch
- ตัดสินใจ tracking provider + mapping mode ได้
- **Go / No-go:** ถ้าคลิกเป้า ≥ 44pt แม่นไม่ถึง 90% → ลดบทบาท gesture ให้เป็น "pointing for context" เป็นหลัก แล้วเดินหน้า Phase 2 (Voice) ก่อน

### Phase 1 — Foundation (2 สัปดาห์)

**เป้าหมาย:** โครงแอปที่พร้อมให้ทุก subsystem เสียบเข้ามา

- Menu bar app, Settings window, onboarding ขอ permission ทีละตัวพร้อมเหตุผล
- Config (JSON ใน Application Support), Logging (OSLog), typed event stream
- Packages แยกตาม §3.2 + CI build/test

**Exit criteria:** แอปรันเป็น menu bar, ขอ/ตรวจ permission ได้ครบ, `swift test` ผ่านทุก package

### Phase 2 — Gesture Core (3–4 สัปดาห์)

**เป้าหมาย:** ควบคุม cursor พื้นฐานได้อย่างเสถียรและไม่เกิดคำสั่งโดยไม่ตั้งใจ

- Camera pipeline นอก main thread, tracking provider ที่เลือกจาก P0
- One Euro filter, dead zone, acceleration, calibration
- Clutch (engage/disengage), state machine, move / click / right click / double click / drag / scroll
- HUD overlay แสดงสถานะ tracking + ไฟบอกว่ากล้องทำงาน
- Idle mode fps ต่ำ / ปิดกล้องอัตโนมัติ

**Exit criteria (วัดได้):**
- Latency end-to-end < 80ms (p95)
- คลิกเป้า ≥ 44pt แม่น ≥ 95%
- False click < 1 ครั้ง / 5 นาที ระหว่างใช้งานปกติ (พิมพ์งาน, หยิบแก้ว)
- CPU < 15% บน Apple Silicon ขณะ tracking

### Phase 3 — Voice + AI Assistant (3–4 สัปดาห์)

**เป้าหมาย:** สั่งงานด้วยเสียงและให้ AI เรียก tool พื้นฐานได้อย่างปลอดภัย

- Push-to-talk (hotkey / gesture), STT on-device (ไทย + อังกฤษ + ปนกัน)
- LLMProvider protocol + Anthropic implementation + tool calling
- Tool ชุดแรก (low-risk): volume, media, open app, focus window, clipboard read
- Policy Engine v1 (risk levels) + Confirmation UI + Audit log
- TTS + HUD แสดงคำตอบ, conversation context ภายใน session

**Exit criteria:** คำสั่งเสียงพื้นฐาน 20 แบบสำเร็จ ≥ 90% (ทั้งไทยและอังกฤษ), ไม่มี tool ใดรันโดยไม่ผ่าน Policy Engine (มี test บังคับ)

### Phase 4 — Point + Speak ⭐ (3 สัปดาห์)

**เป้าหมาย:** สร้างจุดขายหลัก — ชี้แล้วพูด

- Resolve สิ่งที่ถูกชี้: `AXUIElementCopyElementAtPosition` → ไฟล์ใน Finder / หน้าต่าง / ข้อความ / UI element
- Fallback: crop screenshot รอบจุดที่ชี้ → VisionModelProvider
- InputFusion: จับคู่ "ช่วงเวลาที่ชี้" กับ "คำว่า อันนี้ / ตรงนี้ / this / that" ในคำพูด
- ส่ง context ที่ resolve ได้เข้า LLM เป็น structured data

**Exit criteria:** demo 5 scenario ใน §1.1 ทำงานได้ end-to-end, ผู้ทดสอบ 3 คนทำได้โดยไม่ต้องอธิบายเพิ่ม

### Phase 5 — Context Engine + Advanced Gestures (3 สัปดาห์)

- Active app detection, App Profiles (Chrome, Spotify, VS Code, Keynote/PowerPoint)
- Swipe, pinch-zoom, system controls (volume, brightness, Mission Control, desktop switching)
- แก้ gesture ที่ชนกัน: ใช้ mode / ท่าเริ่มต้นต่างกัน / มือที่สอง
- Gesture mapping editor ใน Settings
- Wake word ("Hey KAI") — optional, local only

**Exit criteria:** ผู้ใช้สร้าง profile เองได้จาก UI, ไม่มี gesture คู่ใดใน profile เดียวกันที่ตีความกำกวม (มี validator)

### Phase 6 — Agent + MCP (4–6 สัปดาห์)

- Agent loop: observe → think → plan → act → observe, มี step limit + cancel
- MCP client (ใช้ server ภายนอก: filesystem, browser, ฯลฯ)
- MCP server (เปิด tool ของ KAI ให้ Claude Code / agent อื่นใช้)
- Policy Engine v2: ประเมินความเสี่ยงที่ระดับ argument (เช่น command ใน terminal), scoped "Always Allow"
- Prompt injection defense: แยก user instruction กับ untrusted content, high-risk action ห้ามเริ่มจาก content ที่อ่านมา
- Undo / dry-run สำหรับ file operations, Activity timeline UI

**Exit criteria:** ผ่าน red-team test suite (prompt injection จากเว็บ/ไฟล์/หน้าจอ) 100%, agent ทำ task หลายขั้นตอน 10 แบบสำเร็จ ≥ 80%

### Phase 7 — Coding Agent (3 สัปดาห์)

- Orchestrate coding agent ที่มีอยู่ (Claude Code, Codex CLI) แทนการสร้างเอง
- Voice → task brief → ส่งให้ coding agent → ติดตามสถานะ → สรุปผลด้วยเสียง
- Point + Speak กับโค้ด/error บนหน้าจอ

**Exit criteria:** "KAI, fix the failing test" ทำงาน end-to-end บน repo ตัวอย่าง

---

## 6. Success Metrics (ภาพรวม)

| Metric | Target |
| --- | --- |
| Cursor latency (p95) | < 80ms |
| Click accuracy (≥ 44pt) | ≥ 95% |
| False activation | < 1 / 5 นาที |
| CPU ขณะ tracking | < 15% |
| Voice command success | ≥ 90% |
| Voice → first response | < 1.5s |
| Unauthorized tool execution | 0 |

---

## 7. Risks & Mitigations

| ความเสี่ยง | ผลกระทบ | วิธีลด |
| --- | --- | --- |
| Webcam tracking ไม่แม่นพอ | สูง | Spike P0 + Go/No-go, pivot เป็น pointing-for-context |
| แขนล้า (gorilla arm) | สูง | Relative mode, ใช้ได้ทั้งมือวางบนโต๊ะ, ไม่บังคับใช้ต่อเนื่อง |
| กล้อง MacBook ไม่เห็นมือ | กลาง | Calibration, รองรับกล้องภายนอก / iPhone Continuity Camera |
| Gesture โดยไม่ตั้งใจ | สูง | Clutch, cooldown, confidence threshold |
| แบตเตอรี่ / ความร้อน | กลาง | Idle fps ต่ำ, auto-off, วัด CPU ทุก release |
| STT ภาษาไทยปนอังกฤษไม่แม่น | กลาง | ทดสอบเร็ว, สำรองด้วย whisper.cpp |
| Prompt injection | สูงมาก | แยก trust level ของ input, red-team suite, policy ห้าม high-risk จาก untrusted |
| Private API (brightness, Mission Control) พังเมื่อ macOS อัปเดต | กลาง | แยกไว้หลัง protocol, feature flag, fallback ด้วย key event |
| Scope creep | สูง | ยึด exit criteria, ไม่เริ่ม phase ถัดไปจนกว่าจะผ่าน |
| ชื่อ "KAI" ชน trademark | ต่ำ–กลาง | ตรวจสอบก่อนทำ branding / public release |

---

## 8. Open Questions

- [ ] Business model: ฟรี / subscription / BYO API key?
- [ ] รองรับ iPhone Continuity Camera เป็นกล้องหลักตั้งแต่ Phase 2 ไหม?
- [ ] ต้องการ local LLM เป็น first-class ตั้งแต่ Phase 3 หรือหลัง Phase 6?
- [ ] Wake word จำเป็นจริงไหม หรือ push-to-talk + gesture เพียงพอ?
- [ ] จะเก็บ conversation memory ข้าม session หรือไม่ และเก็บที่ไหน?
