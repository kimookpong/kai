# KAI — Tasks

> อ้างอิง: [PLAN.md](PLAN.md) · [CONCEPT.md](CONCEPT.md)

**รูปแบบ:** `[ ] ID — งาน` ตามด้วย **Done when** (เกณฑ์ว่าเสร็จ) และ `deps:` ถ้ามีงานที่ต้องเสร็จก่อน
ไม่เริ่ม phase ถัดไปจนกว่า **Phase Gate** ของ phase ปัจจุบันจะผ่าน

---

## Phase 0 — Feasibility Spike

- [x] **P0-01** — สร้าง Swift command-line / minimal app สำหรับ spike (แยกจากโปรเจกต์หลัก, ทิ้งได้)
- [x] **P0-02** — Capture กล้องด้วย AVFoundation ที่ 30 และ 60 fps (ถ้ากล้องรองรับ) _ทดสอบที่ ~28–30 fps; 60 fps ยังไม่ได้ลอง_
  - Done when: แสดง preview + วัด fps จริงได้
- [x] **P0-03** — Hand landmarks ด้วย Apple Vision (`VNDetectHumanHandPoseRequest`)
  - Done when: วาด 21 จุดบน preview ได้, log confidence ต่อจุด
  - deps: P0-02
- [ ] **P0-04** — Hand landmarks ด้วย MediaPipe (Hand Landmarker) _ข้าม: Apple Vision เพียงพอ ตัดสินใจโดยผู้ใช้ให้หยุดทดสอบ_
  - Done when: วาด 21 จุด + ค่า z ได้
  - deps: P0-02
- [x] **P0-05** — ขยับ cursor ด้วย `CGEvent` จาก landmark _เทียบ anchor แล้ว: mcp ดีที่สุด (ดู docs/spike-results.md)_
  - ทดลอง anchor 3 แบบ: ปลายนิ้วชี้ / โคนนิ้วชี้ (MCP) / กลางฝ่ามือ
  - deps: P0-03
- [x] **P0-06** — Implement One Euro Filter + ทดลองปรับ `minCutoff`, `beta`
- [ ] **P0-07** — ทดลอง Absolute vs Relative mapping _absolute ใช้ได้ผลแล้ว; relative ไม่มีข้อมูล ข้ามตามที่ผู้ใช้สั่งหยุดทดสอบ; ใช้ absolute_
- [x] **P0-08** — Pinch detection (ระยะ thumb tip ↔ index tip, normalize ด้วยขนาดมือ) + freeze cursor ตอนเริ่ม pinch _ต้องมี debounce 2 เฟรม + re-arm หลังมือหาย (ดู docs/spike-results.md)_
- [x] **P0-09** — เครื่องมือวัดผล
  - Latency: timestamp เฟรม → timestamp CGEvent
  - Jitter: std dev ของตำแหน่ง cursor ตอนมือนิ่ง 5 วินาที
  - CPU % / fps
  - Click test: เป้าสุ่มขนาด 24 / 44 / 64 pt, นับ hit rate
- [ ] **P0-10** — ทดสอบในสภาพแสงต่าง ๆ (กลางวัน, ไฟห้อง, แสงน้อย) และระยะห่าง 40 / 60 / 90 cm _ข้ามไว้ก่อน: ยังไม่ได้ทดสอบแสงน้อย/ระยะ_
- [ ] **P0-11** — ทดสอบมุมกล้อง MacBook built-in vs กล้องภายนอก / Continuity Camera _ข้ามไว้ก่อน: ทดสอบเฉพาะกล้อง built-in_
- [x] **P0-12** — เขียนผลลงใน `docs/spike-results.md` + ตัดสินใจ _Go แบบมีเงื่อนไข: Apple Vision + mcp + absolute (ดู docs/spike-results.md)_
  - Tracking provider · Mapping mode · Anchor point · ค่า filter เริ่มต้น

**🚦 Phase Gate P0:** มี `docs/spike-results.md` พร้อมตัวเลข และตัดสิน Go / No-go ตาม PLAN.md §5 — ✅ ผ่านแบบมีเงื่อนไข (click 27/30, latency p95 ~90 ms และ CPU ~25% ยังเกินเกณฑ์ ต้องติดตามใน Phase 2)

---

## Phase 1 — Foundation

### Project setup
- [x] **P1-01** — สร้าง `KAI.xcodeproj` (macOS 14+, Swift 6, SwiftUI app lifecycle)
- [ ] **P1-02** — สร้าง local Swift packages: `KAICore`, `KAITracking`, `KAIGesture`, `KAIActions`, `KAIContext`, `KAIVoice`, `KAIAgent`, `KAIMCP` _ทำแล้วเฉพาะ `KAICore` (Packages/KAICore); ที่เหลือสร้างเมื่อมีโค้ดจริง_
  - Done when: app target link ได้ทุก package, แต่ละ package มี test target
- [x] **P1-03** — ปิด App Sandbox, ตั้ง Hardened Runtime, entitlements (camera, microphone, apple-events)
- [x] **P1-04** — `.gitignore`, SwiftLint / swift-format config
- [x] **P1-05** — CI (GitHub Actions): build + `swift test` ทุก package _เขียน workflow แล้ว ยังไม่เคยรันบน GitHub_

### Core
- [x] **P1-06** — `KAIEvent` enum + `EventStream` (typed `AsyncStream`, multi-subscriber)
- [x] **P1-07** — Configuration: โหลด/บันทึก JSON ใน `~/Library/Application Support/KAI/`, มี schema version + migration
- [x] **P1-08** — Logging ด้วย `OSLog` แยก category ต่อ subsystem
- [x] **P1-09** — Permission model: ตรวจสถานะ Accessibility, Camera, Microphone, Screen Recording, Automation

### App shell
- [x] **P1-10** — Menu bar app (`MenuBarExtra`), ไม่มี Dock icon (`LSUIElement`)
- [ ] **P1-11** — Menu: สถานะ, mode, กล้องที่ใช้, AI status, Settings, Quit _มีสถานะ + จำนวน permission ที่ขาด + Settings + Quit; ยังไม่มี mode / กล้อง / AI status_
- [ ] **P1-12** — Settings window (tabs: General, Gestures, Voice, AI, Permissions, Privacy) _มี General / Permissions / Privacy; แท็บ Gestures / Voice / AI เพิ่มเมื่อมีฟีเจอร์_
- [ ] **P1-13** — Onboarding: ขอ permission ทีละตัว พร้อมคำอธิบายว่าใช้ทำอะไร + ปุ่มเปิด System Settings _มีหน้า Permissions พร้อมเหตุผลและปุ่ม Allow / Open System Settings; ยังไม่มี flow onboarding ครั้งแรก_
- [x] **P1-14** — Global hotkey (เปิด/ปิด KAI, push-to-talk) _⌃⌥K สลับ engage; push-to-talk รอ Phase 3_
- [x] **P1-15** — Launch at login (`SMAppService`)

**🚦 Phase Gate P1:** แอปรันเป็น menu bar, onboarding ครบ, CI เขียว

---

## Phase 2 — Gesture Core

### Tracking pipeline
- [x] **P2-01** — `CameraManager` (เลือกกล้อง, fps, รันบน dedicated queue) _รวมอยู่ใน AppleVisionTracker (เลือกกล้อง/fps ยังไม่มี ใช้กล้องเริ่มต้น VGA)_
  - deps: P1-09
- [x] **P2-02** — `HandTrackingProvider` protocol + implementation ที่เลือกจาก P0 _protocol `HandTrackingProvider` อยู่ใน KAITracking; implementation ของ Apple Vision ยังอยู่ใน spike/ รอย้าย_ _AppleVisionTracker ใน KAITracking; ยังไม่ได้วัดผลหลังย้ายจาก spike_
- [x] **P2-03** — `HandLandmarks` model (normalized coords, confidence, handedness) _ยังไม่มี handedness (ไม่ได้ใช้ใน Phase 2)_
- [ ] **P2-04** — Idle mode: ลด fps เมื่อไม่เห็นมือ N วินาที, ปิดกล้องเมื่อ disengage นาน _ปิดกล้องเมื่อ disengage แล้ว; ยังไม่มีการลด fps ตอนไม่เห็นมือ_
- [ ] **P2-05** — Camera-active indicator ใน menu bar (นอกเหนือจากไฟเขียวของระบบ) _ไอคอน menu bar เปลี่ยนเมื่อ engaged; ยังไม่มีตัวบอกกล้องแยก_

### Signal processing
- [x] **P2-06** — One Euro Filter (unit tests ด้วย synthetic signal)
- [ ] **P2-07** — Dead zone + acceleration curve (ปรับได้ใน config)
- [ ] **P2-08** — Calibration flow: ให้ผู้ใช้ชี้ 4 มุมจอ → สร้าง mapping region
- [ ] **P2-09** — Multi-monitor mapping

### Gesture engine
- [x] **P2-10** — `GestureStateMachine` (IDLE → HAND_DETECTED → ENGAGED → TRACKING → PINCH → DRAG → RELEASE) _GestureEngine: idle / tracking / pinching + clutch (engaged flag); ท่า drag ยังรอ_
  - Done when: state transitions มี unit test ครบ รวมกรณีมือหายกลางคัน
- [ ] **P2-11** — Clutch: engage / disengage gesture (เช่น โชว์ฝ่ามือค้าง 0.5s) + hotkey
- [ ] **P2-12** — Recognizers: pinch, pinch-hold, two-finger pinch, scroll pose _PinchDetector เสร็จ (hysteresis, debounce, speed gate, re-arm); pinch นิ้วชี้ + นิ้วกลางเสร็จ (นิ้วที่ใกล้โป้งกว่าชนะ, ค้างอยู่เมินอีกนิ้ว); scroll pose รอ_
  - แต่ละตัวมี threshold, confidence, min/max duration, cooldown
- [x] **P2-13** — `GestureEvent` + `ActionMapper` (gesture → action ตาม config, ยังไม่ต้องมี app profile) _ActionMapper มีแค่ pinch → leftButton; gesture อื่นรอ Phase 5_

### Actions
- [ ] **P2-14** — `MouseController`: move, left/right/double click, drag, scroll (vertical + horizontal) _ทำแล้ว: move, ปุ่มซ้าย (กด/ปล่อย → ลากได้), double click (นับคลิกด้วย ClickCounter; ยังไม่ทดสอบกับแอปจริง); right click = จีบโป้งกับนิ้วกลาง (ยังไม่ทดสอบกับแอปจริง); ยังไม่มี scroll_
- [ ] **P2-15** — ป้องกัน feedback loop: ไม่ให้ cursor event ที่ KAI สร้างถูกตีความซ้ำ

### UX
- [ ] **P2-16** — HUD overlay (โปร่งใส, click-through): จุด cursor ของ KAI, สถานะ engaged, progress ของ pinch
- [ ] **P2-17** — Debug view: preview กล้อง + landmarks + กราฟ jitter (เปิดจาก Settings)

### Validation
- [ ] **P2-18** — Click-test harness (ใช้ซ้ำจาก P0-09) ในโหมด debug
- [ ] **P2-19** — False-activation test: ใช้งานปกติ 5 นาที (พิมพ์, หยิบแก้ว, เกาหัว) นับ click ที่ไม่ตั้งใจ

**🚦 Phase Gate P2:** latency p95 < 80ms · click ≥ 44pt ≥ 95% · false click < 1/5 นาที · CPU < 15%

---

## Phase 3 — Voice + AI Assistant

### Voice
- [ ] **P3-01** — `SpeechToTextProvider` protocol + Apple Speech (on-device) implementation
- [ ] **P3-02** — ทดสอบ STT ไทย / อังกฤษ / ไทยปนอังกฤษ ด้วยชุดประโยค 50 ประโยค → บันทึก WER
- [ ] **P3-03** — (ถ้า P3-02 ไม่ผ่าน) whisper.cpp provider
- [ ] **P3-04** — Push-to-talk ผ่าน hotkey และ gesture
- [ ] **P3-05** — `TextToSpeechProvider` (AVSpeechSynthesizer) + เลือกเสียงไทย/อังกฤษ
- [ ] **P3-06** — Microphone-active indicator

### AI
- [ ] **P3-07** — `LLMProvider` protocol (messages, tool calling, streaming)
- [ ] **P3-08** — Anthropic implementation (API key เก็บใน Keychain)
- [ ] **P3-09** — Ollama / local implementation (ขั้นต่ำ: chat + tool calling ถ้า model รองรับ)
- [ ] **P3-10** — Conversation context ภายใน session (+ ปุ่ม clear)
- [ ] **P3-11** — System prompt + ข้อมูล context (active app, เวลา, ภาษา)

### Tools & Safety
- [ ] **P3-12** — `Tool` protocol: name, description, JSON schema, `riskLevel`, `execute()`
- [ ] **P3-13** — `ToolRegistry`
- [ ] **P3-14** — `PolicyEngine` v1: low → auto, medium → ตาม config, high → ต้อง confirm เสมอ
- [ ] **P3-15** — `ToolExecutor` ที่บังคับผ่าน PolicyEngine (test: ไม่มี code path ที่ execute โดยตรง)
- [ ] **P3-16** — Confirmation UI: [Cancel] [Allow Once] [Always Allow for …]
- [ ] **P3-17** — Audit log (ทุก tool call: เวลา, input, การตัดสิน policy, ผลลัพธ์)
- [ ] **P3-18** — Tools ชุดแรก: `volume.get/set`, `media.play/pause/next/prev`, `app.open`, `window.focus`, `clipboard.read`

### UX
- [ ] **P3-19** — Assistant HUD: แสดง transcript สด, สถานะ thinking, คำตอบ
- [ ] **P3-20** — ชุดทดสอบคำสั่งเสียง 20 แบบ (ไทย + อังกฤษ) เป็น regression suite

**🚦 Phase Gate P3:** คำสั่งเสียง 20 แบบ สำเร็จ ≥ 90% · 0 tool execution ที่ไม่ผ่าน policy

---

## Phase 4 — Point + Speak ⭐

- [ ] **P4-01** — `PointingResolver`: ตำแหน่งที่ชี้ → `AXUIElementCopyElementAtPosition` → role, title, value, URL/path
- [ ] **P4-02** — Resolver เฉพาะ: ไฟล์ใน Finder (path), หน้าต่าง (app + window id), ข้อความที่เลือก, ลิงก์ในเบราว์เซอร์
- [ ] **P4-03** — Fallback: crop screenshot รอบจุดที่ชี้ (ต้องมี Screen Recording permission)
- [ ] **P4-04** — `VisionModelProvider` protocol + implementation (ส่ง crop ให้ vision LLM)
- [ ] **P4-05** — Pointing history buffer (เก็บ ~3 วินาทีล่าสุดพร้อม timestamp)
- [ ] **P4-06** — `InputFusion`: จับคู่คำ deictic (อันนี้, ตรงนี้, นี่, this, that, here) กับ timestamp ใน transcript → เป้าที่ชี้ ณ เวลานั้น
- [ ] **P4-07** — ส่ง pointed target เข้า LLM เป็น structured context (ไม่ใช่ free text)
- [ ] **P4-08** — Visual feedback: highlight สิ่งที่ KAI เข้าใจว่าถูกชี้ ก่อน execute
- [ ] **P4-09** — Tools เพิ่ม: `window.move(toDisplay)`, `file.reveal`, `file.share`, `screen.describe(region)`
- [ ] **P4-10** — Demo scenarios 5 แบบ (ส่งไฟล์, ย้ายหน้าต่าง, อธิบาย error, สรุปข้อความที่ชี้, เปิดลิงก์ที่ชี้)
- [ ] **P4-11** — Usability test กับผู้ทดสอบ 3 คน + บันทึกผล

**🚦 Phase Gate P4:** demo 5 scenario ผ่าน end-to-end · ผู้ทดสอบ 3/3 ทำได้โดยไม่ต้องอธิบายเพิ่ม

---

## Phase 5 — Context Engine + Advanced Gestures

### Context
- [ ] **P5-01** — `ActiveApplication` monitor (`NSWorkspace` notifications)
- [ ] **P5-02** — `AppProfile` model + โหลดจาก config
- [ ] **P5-03** — ActionMapper เลือก mapping ตาม active app (fallback → default profile)
- [ ] **P5-04** — Built-in profiles: Chrome/Safari, Spotify/Music, VS Code, Keynote/PowerPoint

### Gestures
- [ ] **P5-05** — Swipe recognizer (4 ทิศ, velocity threshold)
- [ ] **P5-06** — Pinch-zoom recognizer
- [ ] **P5-07** — Mode system เพื่อแก้ท่าชนกัน (cursor mode / system-control mode)
- [ ] **P5-08** — Profile validator: แจ้งเตือนเมื่อ gesture สองตัวใน profile เดียวกันกำกวม

### System actions
- [ ] **P5-09** — `KeyboardController` (key events, shortcuts)
- [ ] **P5-10** — `BrightnessController`: DDC/CI สำหรับจอนอก, DisplayServices (private) สำหรับ built-in หลัง feature flag
- [ ] **P5-11** — Mission Control / desktop switching / show desktop (ผ่าน key events)
- [ ] **P5-12** — Shortcuts.app integration (เรียก shortcut ของผู้ใช้เป็น action)

### UX
- [ ] **P5-13** — Gesture mapping editor ใน Settings (เลือก gesture → action, ต่อ profile)
- [ ] **P5-14** — Import / export profile เป็น JSON

### Wake word (optional)
- [ ] **P5-15** — `WakeWordProvider` protocol + local implementation สำหรับ "Hey KAI"
- [ ] **P5-16** — วัด false wake rate ในบทสนทนาภาษาไทยปกติ 30 นาที

**🚦 Phase Gate P5:** ผู้ใช้สร้าง profile เองได้จาก UI · validator ไม่พบความกำกวมใน built-in profiles

---

## Phase 6 — Agent + MCP

### Agent loop
- [ ] **P6-01** — Agent loop: observe → think → act → observe, มี max steps + timeout
- [ ] **P6-02** — Cancel ได้ทุกเมื่อ (hotkey / เสียง "หยุด" / gesture)
- [ ] **P6-03** — Error recovery: retry ด้วยกลยุทธ์ต่าง, ถามผู้ใช้เมื่อติด
- [ ] **P6-04** — Progress reporting ระหว่างทำงาน (HUD + TTS แบบสั้น)

### MCP
- [ ] **P6-05** — MCP client (stdio + HTTP transports), จัดการ server ใน Settings
- [ ] **P6-06** — แปลง MCP tools เข้า ToolRegistry พร้อมกำหนด risk level (default: medium)
- [ ] **P6-07** — MCP server: เปิด tool ของ KAI (mouse, keyboard, window, volume, pointing) ให้ agent ภายนอก
- [ ] **P6-08** — ทุก call จาก MCP server ภายนอกยังต้องผ่าน PolicyEngine

### Tools เพิ่ม
- [ ] **P6-09** — `filesystem` (read/list/move/trash — ไม่มี permanent delete)
- [ ] **P6-10** — `terminal.execute` (sandbox ด้วย working dir, timeout, output limit)
- [ ] **P6-11** — `applescript.run` / `shortcuts.run`
- [ ] **P6-12** — `ui.inspect` (AX tree) / `ui.click(element)`
- [ ] **P6-13** — `screenshot` + vision model (ใช้เป็นทางเลือกสุดท้าย)

### Safety
- [ ] **P6-14** — PolicyEngine v2: risk ระดับ argument (classifier สำหรับ shell command: read-only / write / destructive / network)
- [ ] **P6-15** — Scoped "Always Allow" (command pattern + directory + หมดอายุ)
- [ ] **P6-16** — Trust levels: แยก user instruction vs untrusted content (web, file, screen, MCP output)
- [ ] **P6-17** — Rule: high-risk action ที่มีที่มาจาก untrusted content → ต้อง confirm เสมอ + แสดงที่มา
- [ ] **P6-18** — Voice-only ไม่พอสำหรับ high-risk → ต้อง confirm ด้วย click / gesture
- [ ] **P6-19** — Undo stack สำหรับ file operations (move/trash) + dry-run mode
- [ ] **P6-20** — Activity timeline UI ("KAI ทำอะไรไปบ้างวันนี้") จาก audit log

### Validation
- [ ] **P6-21** — Red-team suite: prompt injection จากหน้าเว็บ, ไฟล์, ข้อความบนจอ, MCP output (≥ 20 cases)
- [ ] **P6-22** — Multi-step task suite 10 แบบ

**🚦 Phase Gate P6:** red-team 100% ผ่าน · multi-step tasks สำเร็จ ≥ 80%

---

## Phase 7 — Coding Agent

- [ ] **P7-01** — `CodingAgentProvider` protocol (start task, stream progress, cancel, result)
- [ ] **P7-02** — Claude Code integration (headless mode)
- [ ] **P7-03** — Codex CLI integration
- [ ] **P7-04** — Project registry: map ชื่อที่พูด ("motion project") → path ของ repo
- [ ] **P7-05** — Voice → task brief (LLM สรุปคำสั่ง + context ที่ชี้ เป็น brief ที่ชัด)
- [ ] **P7-06** — Point + Speak กับโค้ด/error บนจอ → แนบเป็น context ให้ coding agent
- [ ] **P7-07** — สรุปผลด้วยเสียง + เปิด diff ให้ดู
- [ ] **P7-08** — Confirmation ก่อน commit / push

**🚦 Phase Gate P7:** "KAI, fix the failing test" ทำงาน end-to-end บน repo ตัวอย่าง

---

## Cross-cutting (ทำต่อเนื่องทุก phase)

- [ ] **X-01** — วัด CPU / แบตเตอรี่ / memory ทุก release
- [ ] **X-02** — Privacy review ก่อนเพิ่มข้อมูลใหม่ที่ส่งออกนอกเครื่อง
- [ ] **X-03** — Accessibility: VoiceOver สำหรับ UI ของ KAI, ขนาดตัวอักษร, contrast
- [ ] **X-04** — Localization: ไทย + อังกฤษ
- [ ] **X-05** — Code signing + notarization pipeline (ก่อน release แรก)
- [ ] **X-06** — Auto-update (Sparkle)
- [ ] **X-07** — Trademark check ชื่อ "KAI" ก่อน public release
- [ ] **X-08** — Design: logo / icon ตามแนว Japanese minimal (CONCEPT.md §25)
