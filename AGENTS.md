# AGENTS.md

คู่มือสำหรับ AI coding agents (Claude Code, Codex, ฯลฯ) และนักพัฒนาที่ทำงานใน repo นี้

---

## 1. Project

**KAI (ไค)** — AI companion สำหรับ macOS ที่รวม hand gesture, voice และ AI agent เข้าด้วยกัน
จุดขายหลักคือ **Point + Speak**: ผู้ใช้ชี้แล้วพูด และ KAI ใช้สิ่งที่ถูกชี้เป็น context

| เอกสาร | ใช้เมื่อ |
| --- | --- |
| [CONCEPT.md](CONCEPT.md) | เข้าใจ vision และเหตุผลของ product |
| [PLAN.md](PLAN.md) | สถาปัตยกรรม, technical decisions, roadmap, exit criteria — **แหล่งความจริงหลัก** |
| [TASKS.md](TASKS.md) | รายการงานที่ต้องทำ แยกตาม phase |

ถ้า CONCEPT.md กับ PLAN.md ขัดกัน ให้ยึด **PLAN.md**

---

## 2. Workflow

1. **เลือกงานจาก [TASKS.md](TASKS.md)** ตาม ID (เช่น `P2-06`) ทำเฉพาะ phase ปัจจุบัน ห้ามข้าม Phase Gate
2. ตรวจ `deps:` ของงานนั้นว่าเสร็จแล้ว
3. อ่านส่วนที่เกี่ยวข้องใน PLAN.md ก่อนเขียนโค้ด
4. ทำงานให้ครบตาม **Done when**
5. เขียน / อัปเดต test
6. รัน build + test ให้ผ่าน (§4)
7. ติ๊ก `[x]` ใน TASKS.md สำหรับงานที่เสร็จ
8. Commit (§7)

ถ้าจำเป็นต้องเปลี่ยน technical decision ที่ระบุใน PLAN.md §4 — **หยุดและถามผู้ใช้ก่อน** อย่าเปลี่ยนเอง

---

## 3. Repository Layout

```text
project.yml                 XcodeGen spec -> KAI.xcodeproj (generated, gitignored)
KAI/                        App target: menu bar, UI, onboarding
Packages/
├── KAICore                 Events, Config, Logging, Permissions model
├── KAITracking             HandTrackingProvider + implementations
├── KAIGesture              Filters, GestureStateMachine, Recognizers, ActionMapper
├── KAIActions              Mouse / Keyboard / Window / Volume / Brightness / Media
├── KAIContext              Active app, AX element-at-point, AppProfiles
├── KAIVoice                STT / TTS / WakeWord providers
├── KAIAgent                LLMProvider, ToolRegistry, PolicyEngine, Agent loop, AuditLog
└── KAIMCP                  MCP client + server
spike/                      Phase 0 prototype (ทิ้งได้, ไม่ import เข้าแอปหลัก)
docs/                       ผล spike, design notes, ADRs
```

**Dependency direction (ห้ามย้อนทาง):**

```text
App → KAIAgent / KAIVoice / KAIGesture / KAIMCP → KAIActions / KAIContext / KAITracking → KAICore
```

- `KAICore` ห้าม import package อื่นของ KAI
- `KAIGesture` ห้ามรู้จัก `KAIAgent` (fast path ต้องไม่ขึ้นกับ AI)
- UI code อยู่ใน app target เท่านั้น ไม่อยู่ใน packages

---

## 4. Build & Test

```bash
# test ทุก package
for p in Packages/*; do swift test --package-path "$p" || exit 1; done
```

```bash
# generate KAI.xcodeproj from project.yml (needs: brew install xcodegen; the .xcodeproj is not committed)
xcodegen generate
```

```bash
# build app
xcodebuild -project KAI.xcodeproj -scheme KAI -configuration Debug build
```

```bash
# lint / format
swift-format lint -r KAI Packages
```

ก่อน commit ต้อง: build ผ่าน, test ผ่าน, ไม่มี warning ใหม่

งานที่ต้องใช้กล้อง / ไมค์ / Accessibility จริง test อัตโนมัติไม่ได้ — ให้แยก logic ออกมา test ด้วย mock provider และระบุใน commit ว่าส่วนไหนยังไม่ได้ทดสอบบนเครื่องจริง

---

## 5. Coding Conventions

### Swift
- Swift 6, strict concurrency เปิด, macOS 14+
- SwiftUI สำหรับ UI, AppKit เฉพาะเมื่อ SwiftUI ทำไม่ได้ (overlay window, event tap)
- ใช้ `async/await` และ `actor` แทน callback / GCD ในโค้ดใหม่ (ยกเว้น camera capture queue)
- Event ระหว่าง subsystem ใช้ typed `AsyncStream<KAIEvent>` จาก `KAICore` — ห้ามใช้ `NotificationCenter` สำหรับ event ภายใน
- Logging ใช้ `Logger` (OSLog) แยก category ต่อ subsystem — ห้ามใช้ `print`

### Providers
ทุก provider ที่อาจเปลี่ยนได้ต้องอยู่หลัง protocol:
`HandTrackingProvider`, `SpeechToTextProvider`, `TextToSpeechProvider`, `WakeWordProvider`,
`LLMProvider`, `VisionModelProvider`, `CodingAgentProvider`

ห้าม hard-code ชื่อ model / provider ในโค้ดนอก implementation ของ provider นั้น

### Naming
- `HandTrackingProvider` = hand landmarks จากกล้อง
- `VisionModelProvider` = vision LLM สำหรับเข้าใจภาพหน้าจอ
- อย่าใช้คำว่า `VisionProvider` เฉย ๆ (กำกวม)

### Config
- ค่าที่ผู้ใช้ปรับได้ (threshold, filter params, mappings) อยู่ใน config ไม่ใช่ constant ในโค้ด
- เปลี่ยน schema ต้องเพิ่ม version + migration

---

## 6. Critical Rules

### 6.1 Fast path (real-time)
- โค้ดใน pipeline `Camera → Tracking → Filter → Gesture → Action` **ห้ามรันบน main thread**
- ห้าม allocate หนัก, ห้าม network, ห้าม await LLM ใน fast path
- งบเวลา < 16ms ต่อเฟรม — ถ้าแก้โค้ดใน path นี้ให้วัด latency ด้วย debug harness

### 6.2 Agent safety (ห้ามละเมิด)
- **ทุก tool execution ต้องผ่าน `ToolExecutor` → `PolicyEngine`** ห้ามมี code path ที่เรียก action โดยตรงจาก LLM output
- Tool ใหม่ทุกตัวต้องประกาศ `riskLevel` และมี test ว่าผ่าน policy
- High-risk action ต้อง confirm เสมอ และ **ห้ามยืนยันด้วยเสียงอย่างเดียว**
- Content ที่อ่านมาจากเว็บ / ไฟล์ / หน้าจอ / MCP output เป็น **untrusted** — ห้ามใช้เป็นที่มาของคำสั่ง high-risk โดยไม่ confirm
- ไม่มี tool ที่ลบไฟล์ถาวร — ใช้ move to Trash เท่านั้น
- ทุก tool call ต้องบันทึกใน audit log

### 6.3 Privacy
- Camera frames ห้ามเขียนลง disk หรือส่งออกนอกเครื่อง ยกเว้น crop หน้าจอใน Point + Speak ที่ผู้ใช้เปิด cloud vision ไว้
- Hand tracking, wake word ทำบนเครื่องเท่านั้น
- API key เก็บใน Keychain — ห้ามอยู่ใน config file, log หรือ repo
- ห้าม log transcript, screen content หรือ file content ในระดับ default (ใช้ `.private` ใน OSLog)

### 6.4 Gesture engine
- ห้ามยิง action จาก frame เดียว — ต้องผ่าน `GestureStateMachine`
- ทุก recognizer ต้องมี confidence threshold, min duration และ cooldown
- ไม่มี gesture ใดทำงานถ้ายังไม่ engaged (clutch)

### 6.5 Private API
- Private API (เช่น DisplayServices) ต้องอยู่หลัง protocol + feature flag + มี fallback
- ระบุใน comment ว่าเป็น private API

---

## 7. Commits

- รูปแบบ: `<type>(<scope>): <summary>` พร้อม task ID ถ้ามี
  - type: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `spike`
  - scope: ชื่อ package ไม่มี prefix (`core`, `gesture`, `agent`, `app`, …)
  - ตัวอย่าง: `feat(gesture): add One Euro filter (P2-06)`
- 1 commit ต่อ 1 task เมื่อเป็นไปได้
- ห้าม commit secrets, `xcuserdata/`, build output, ภาพ / วิดีโอจากกล้อง
- ห้าม push / force-push / แก้ git config โดยที่ผู้ใช้ไม่ได้สั่ง

---

## 8. When to Ask

หยุดและถามผู้ใช้เมื่อ:
- จะเปลี่ยน technical decision ใน PLAN.md §4 หรือ dependency direction ใน §3
- จะเพิ่ม third-party dependency
- จะใช้ private API ใหม่
- จะส่งข้อมูลชนิดใหม่ออกนอกเครื่อง
- Exit criteria ของ phase ไม่ผ่าน และต้องตัดสิน Go / No-go
- งานใน TASKS.md กำกวมหรือขัดกับ PLAN.md

---

## 9. Language

- โค้ด, identifier, commit message, comment ในโค้ด: **อังกฤษ**
- เอกสารใน repo (PLAN, TASKS, docs/): **ไทย** ผสมศัพท์เทคนิคภาษาอังกฤษ
- UI strings: ผ่าน localization (ไทย + อังกฤษ) ห้าม hard-code
