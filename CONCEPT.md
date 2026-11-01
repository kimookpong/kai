# KAI — AI Companion for macOS

> **See. Hear. Think. Act.**

KAI (ไค) is an AI companion for macOS designed to provide a natural, multimodal way to interact with and control a computer.

KAI starts with **hand and finger tracking** as a new input method for controlling macOS, but the long-term vision is much broader:

- Hand / Finger interaction
- Voice interaction
- Visual understanding
- Context awareness
- AI reasoning
- Computer control
- Autonomous task execution
- Coding / development assistance

KAI should evolve from a **gesture controller** into a **general-purpose AI computer agent**.

---

# 1. Product Vision

## Vision

> Build a personal AI companion that allows users to interact with their Mac naturally through hand gestures, voice, and conversation — and eventually allows the AI to perform tasks autonomously on the user's behalf.

KAI should feel less like traditional software and more like a personal computer companion.

The user should eventually be able to say:

```text
"KAI, open my development project."

"KAI, increase the volume."

"KAI, what am I working on?"

"KAI, find the bug in this code."

"KAI, fix it and run the tests."

"KAI, prepare everything for my meeting."
```

KAI should understand the request, determine the appropriate actions, execute them, and report the result.

---

# 2. Product Philosophy

KAI is not primarily a "finger mouse".

Finger tracking is only the first interaction modality.

The core philosophy is:

```text
Natural Input
     ↓
Understanding
     ↓
Reasoning
     ↓
Action
     ↓
Feedback
```

KAI should progressively support:

```text
Hand
Voice
Keyboard
Mouse
Vision
Context
AI
```

All of these should eventually converge into a unified interaction system.

---

# 3. Product Identity

## Name

**KAI**

Thai:

**ไค**

English pronunciation:

**Kai**

The name is intentionally short and easy to pronounce.

Possible Japanese associations include:

- 開 — open
- 解 — solve / understand
- 改 — improve
- 海 — ocean

These meanings align well with KAI's product philosophy:

> Open possibilities. Understand problems. Improve how humans interact with computers.

---

# 4. Tagline

Primary tagline:

> **See. Hear. Think. Act.**

Alternative:

> **Your AI Companion for Mac.**

Possible future positioning:

> **A computer that understands you.**

---

# 5. Long-Term Vision

KAI should eventually become a layer between the human and the computer.

Traditional computing:

```text
Human
  ↓
Keyboard / Mouse
  ↓
Applications
  ↓
Operating System
```

KAI:

```text
Human
  ↓
KAI
  ↓
Understand Intent
  ↓
Reason
  ↓
Execute
  ↓
macOS / Applications / Files / Internet
```

KAI should allow users to focus on **what they want to accomplish**, rather than manually performing every individual computer operation.

---

# 6. Core Capabilities

## 6.1 Vision

KAI can use the camera to understand:

- Hand position
- Finger position
- Hand gestures
- Object/context where appropriate
- Screen context where appropriate
- Visual UI context in future versions

Initial use case:

```text
Camera
  ↓
Hand Tracking
  ↓
Finger Landmarks
  ↓
Gesture Recognition
```

---

## 6.2 Gesture Control

Initial gestures:

| Gesture                     | Action                   |
| --------------------------- | ------------------------ |
| Index finger                | Move cursor              |
| Thumb + index pinch         | Left click               |
| Pinch hold                  | Drag                     |
| Two-finger gesture          | Right click              |
| Hand movement               | Scroll                   |
| Pinch + move                | Zoom                     |
| Swipe left                  | Previous / custom        |
| Swipe right                 | Next / custom            |
| Swipe up                    | Mission Control / custom |
| Swipe down                  | Desktop / custom         |
| Pinch + vertical movement   | Volume                   |
| Pinch + horizontal movement | Brightness / custom      |
| Open palm                   | Pause / activate         |

Gesture mappings must be configurable.

---

# 7. Gesture Engine

Gesture recognition should not directly execute system actions.

Use an abstraction layer:

```text
Camera
   ↓
Hand Tracking
   ↓
Landmarks
   ↓
Gesture Recognition
   ↓
Gesture Event
   ↓
Action Mapping
   ↓
Action Execution
```

Example:

```json
{
  "gesture": "pinch_move_up",
  "action": "volume_up"
}
```

The user should be able to change it:

```json
{
  "gesture": "pinch_move_up",
  "action": "brightness_up"
}
```

This separation is important for future extensibility.

---

# 8. Gesture State Machine

Avoid triggering actions directly from individual frames.

The system should maintain gesture states.

Example:

```text
IDLE
 ↓
HAND_DETECTED
 ↓
INDEX_TRACKING
 ↓
PINCH_DETECTED
 ↓
PINCH_HOLD
 ↓
DRAGGING
 ↓
RELEASE
 ↓
IDLE
```

Gestures should include:

- Detection threshold
- Confidence threshold
- Minimum duration
- Maximum duration
- Cooldown
- Dead zone
- Smoothing
- Velocity
- Acceleration
- Direction

This prevents accidental activation and unstable mouse movement.

---

# 9. Mouse Control

The initial mouse system should support:

- Cursor movement
- Left click
- Right click
- Double click
- Drag
- Scroll
- Horizontal scroll

Cursor movement should use smoothing.

Recommended processing:

```text
Raw Finger Position
       ↓
Normalization
       ↓
Dead Zone
       ↓
Smoothing Filter
       ↓
Velocity
       ↓
Acceleration
       ↓
Cursor Position
```

The goal is to make the cursor feel stable and natural.

---

# 10. Context Awareness

KAI should understand the active application.

Example:

```text
Active App = Chrome
        ↓
Pinch + Move
        ↓
Zoom
```

But:

```text
Active App = Spotify
        ↓
Pinch + Move
        ↓
Volume
```

And:

```text
Active App = PowerPoint
        ↓
Swipe Left / Right
        ↓
Previous / Next Slide
```

The same gesture can therefore have different meanings depending on context.

---

# 11. Application Profiles

KAI should support application-specific gesture profiles.

Example:

```text
Chrome
├── Pinch → Zoom
├── Swipe Left → Back
└── Swipe Right → Forward

Spotify
├── Swipe Left → Previous
├── Swipe Right → Next
├── Swipe Up → Volume +
└── Swipe Down → Volume -

VS Code
├── Swipe → Navigation
├── Gesture → Terminal
└── Voice → Coding Agent

PowerPoint
├── Swipe Left → Previous Slide
├── Swipe Right → Next Slide
└── Open Palm → Pointer
```

Users should be able to create custom profiles.

---

# 12. Voice Interaction

Voice is the second major input modality.

Basic pipeline:

```text
Microphone
    ↓
Speech-to-Text
    ↓
Intent Detection
    ↓
Action / Agent
    ↓
Text-to-Speech
    ↓
Voice Response
```

Examples:

```text
User:
"KAI, increase volume."

KAI:
"Volume increased to 70%."
```

More advanced:

```text
User:
"KAI, open my project and check today's changes."

KAI:
"I'll check the project and summarize today's changes."
```

---

# 13. Conversational AI

KAI should maintain conversational context.

Example:

```text
User:
KAI, open my project.

KAI:
Which project?

User:
The motion project.

KAI:
Opening motionclip.ai.

User:
Check the latest changes.

KAI:
I found three recent changes...
```

The user should not need to repeat context unnecessarily.

---

# 14. Wake Word

Future versions may support a wake word.

Example:

> "Hey KAI"

Then:

```text
Hey KAI
   ↓
Wake Detection
   ↓
Listen
   ↓
Understand
   ↓
Execute
   ↓
Respond
```

The wake-word system should ideally process locally where possible for privacy and responsiveness.

---

# 15. AI Agent

The long-term core of KAI is an AI Agent.

The Agent should be able to:

- Understand user intent
- Plan tasks
- Use tools
- Inspect files
- Execute commands
- Control applications
- Interact with the UI
- Read results
- Recover from errors
- Ask for confirmation when necessary
- Report completed work

Architecture:

```text
User
 ↓
KAI Interface
 ↓
Intent
 ↓
Agent
 ↓
Planner
 ↓
Tool Selection
 ↓
Execution
 ↓
Observation
 ↓
Reasoning
 ↓
Next Action
```

This creates an agent loop:

```text
Observe
   ↓
Think
   ↓
Plan
   ↓
Act
   ↓
Observe
   ↓
Repeat
```

---

# 16. Coding Agent

KAI should eventually integrate with modern coding agents.

Possible integration:

```text
KAI
 ↓
Coding Agent
 ↓
Repository
 ↓
Read Code
 ↓
Plan
 ↓
Edit
 ↓
Run Tests
 ↓
Review
 ↓
Report
```

Example:

```text
User:

"KAI, fix the login bug."

KAI:

"I found the issue in the authentication middleware.
I'll fix it and run the tests."

...

"Done. The authentication tests pass."
```

KAI should not necessarily implement its own coding model.

It can orchestrate existing coding agents and AI models.

Potential integrations may include:

- Codex-style coding agents
- Claude-based agents
- Gemini-based agents
- Local LLMs
- Custom APIs

The architecture should keep the model provider replaceable.

---

# 17. Tool System

KAI should expose tools to the Agent.

Example:

```text
Tools

├── mouse
├── keyboard
├── screenshot
├── camera
├── filesystem
├── terminal
├── browser
├── application
├── window
├── volume
├── brightness
├── media
├── clipboard
└── notifications
```

Each tool should have a clear interface.

Example:

```text
mouse.move(x, y)
mouse.click()
mouse.drag(x, y)
keyboard.type(text)
terminal.execute(command)
window.focus(app)
volume.set(level)
```

---

# 18. Permission System

Because KAI can control macOS, permissions are critical.

Potential permissions:

- Accessibility
- Camera
- Microphone
- Screen Recording
- Automation
- Filesystem
- Network

KAI should clearly communicate why each permission is required.

Never silently perform sensitive operations.

---

# 19. Confirmation System

Actions should have risk levels.

### Low Risk

Can execute automatically:

```text
Increase volume
Open application
Move cursor
Scroll
Change brightness
```

### Medium Risk

May require confirmation depending on configuration:

```text
Delete file
Move file
Send message
Modify settings
```

### High Risk

Always require confirmation:

```text
Delete large datasets
Execute destructive commands
Send external communications
Install software
Change security settings
```

Example:

```text
KAI:

This command will delete 248 files.

[Cancel] [Allow Once] [Always Allow]
```

---

# 20. System Architecture

Recommended high-level architecture:

```text
┌─────────────────────────────────────────┐
│                  KAI                    │
├─────────────────────────────────────────┤
│ Interaction Layer                       │
│                                         │
│ Voice | Gesture | Keyboard | Mouse      │
├─────────────────────────────────────────┤
│ Perception Layer                        │
│                                         │
│ Vision | Hand Tracking | STT            │
├─────────────────────────────────────────┤
│ Intelligence Layer                     │
│                                         │
│ Intent | Context | Memory | Reasoning   │
├─────────────────────────────────────────┤
│ Agent Layer                             │
│                                         │
│ Planner | Tools | Execution | Recovery  │
├─────────────────────────────────────────┤
│ Action Layer                            │
│                                         │
│ macOS APIs | Accessibility | Automation │
├─────────────────────────────────────────┤
│ macOS                                   │
└─────────────────────────────────────────┘
```

---

# 21. Recommended Initial Technology

Target platform:

**macOS**

Recommended language:

**Swift**

UI:

**SwiftUI**

System integration:

- Accessibility APIs
- Core Graphics
- AppKit where required
- Core Media
- AVFoundation
- Vision
- Apple Speech APIs where appropriate

Potential computer vision options:

### Primary

Apple Vision Framework

### Alternative

MediaPipe

The architecture should abstract the tracking provider so it can be replaced later.

---

# 22. Application Architecture

Suggested project structure:

```text
KAI/
│
├── App/
│   ├── KAIApp.swift
│   └── AppDelegate.swift
│
├── Core/
│   ├── EventBus/
│   ├── Configuration/
│   ├── Logging/
│   └── Permissions/
│
├── Camera/
│   ├── CameraManager.swift
│   └── FrameProcessor.swift
│
├── Vision/
│   ├── HandTracker.swift
│   ├── HandLandmark.swift
│   └── VisionProvider.swift
│
├── Gesture/
│   ├── GestureEngine.swift
│   ├── GestureRecognizer.swift
│   ├── GestureStateMachine.swift
│   └── GestureEvent.swift
│
├── Input/
│   ├── VoiceInput.swift
│   ├── KeyboardInput.swift
│   └── MouseInput.swift
│
├── Actions/
│   ├── MouseController.swift
│   ├── KeyboardController.swift
│   ├── WindowController.swift
│   ├── VolumeController.swift
│   ├── BrightnessController.swift
│   └── MediaController.swift
│
├── Context/
│   ├── ActiveApplication.swift
│   └── ContextEngine.swift
│
├── Agent/
│   ├── Agent.swift
│   ├── Planner.swift
│   ├── ToolRegistry.swift
│   ├── ToolExecutor.swift
│   └── Memory.swift
│
├── AI/
│   ├── LLMProvider.swift
│   ├── SpeechProvider.swift
│   └── VisionProvider.swift
│
├── UI/
│   ├── MenuBarView.swift
│   ├── SettingsView.swift
│   ├── GestureSettingsView.swift
│   └── AgentView.swift
│
└── Resources/
```

---

# 23. Menu Bar Application

KAI should primarily operate as a menu bar application.

Example:

```text
┌───────────────────────────┐
│ KAI                       │
│                           │
│ ● Active                  │
│                           │
│ Mode                      │
│   Gesture                 │
│                           │
│ Camera                    │
│   Built-in Camera         │
│                           │
│ AI                        │
│   Ready                   │
│                           │
│ ───────────────────────   │
│                           │
│ Gestures                  │
│ Voice                     │
│ Agent                     │
│ Settings                  │
│                           │
│ Quit KAI                  │
└───────────────────────────┘
```

KAI should not require a large window to remain open.

---

# 24. User Experience

KAI should feel:

- Fast
- Invisible when not needed
- Responsive
- Natural
- Personal
- Intelligent
- Non-intrusive

The user should feel that KAI is always available without constantly demanding attention.

---

# 25. Design Direction

Visual direction:

**Japanese minimal + futuristic technology**

Characteristics:

- Minimal UI
- Clean typography
- Soft geometric shapes
- Subtle Japanese influence
- No excessive gradients
- Premium macOS aesthetic
- Dark / light mode
- Simple iconography

Potential visual symbol:

```text
KAI
開
```

or a minimal abstract symbol representing:

```text
Eye
+
Hand
+
AI
```

Avoid making the logo too obviously related to a mouse.

KAI is an AI companion, not a mouse replacement.

---

# 26. Privacy

Privacy should be a core principle.

Potentially sensitive data includes:

- Camera frames
- Microphone input
- Screen content
- Files
- Terminal commands
- Conversations

KAI should follow:

```text
Local First
Privacy by Design
Explicit Permission
Minimal Data Collection
```

Where technically possible:

- Process hand tracking locally
- Process wake word locally
- Avoid uploading camera frames unnecessarily
- Clearly indicate active camera/microphone
- Allow users to disable cloud AI
- Provide logs/transparency for Agent actions

---

# 27. Development Roadmap

## Phase 0 — Foundation

Goal:

Create the macOS application foundation.

Tasks:

- Swift / SwiftUI project
- Menu bar application
- Settings
- Permission manager
- Logging
- Configuration system

---

## Phase 1 — Gesture Mouse

Goal:

Replace basic mouse interaction with finger tracking.

Features:

- Camera
- Hand tracking
- Index finger tracking
- Cursor movement
- Left click
- Right click
- Drag
- Scroll

Success criteria:

> The user can comfortably operate macOS without a physical mouse for basic operations.

---

## Phase 2 — Advanced Gestures

Features:

- Pinch
- Swipe
- Zoom
- Volume
- Brightness
- Media control
- Mission Control
- Desktop switching
- Custom gesture mapping

---

## Phase 3 — Context Engine

Features:

- Active application detection
- Application profiles
- Context-aware gestures
- Custom mappings
- Shortcut integration

---

## Phase 4 — Voice

Features:

- Speech-to-text
- Text-to-speech
- Voice commands
- Conversation
- Wake word

Example:

```text
"Hey KAI"

"Open Safari."

"Search for today's weather."

"Increase volume."

"Go back."
```

---

## Phase 5 — AI Assistant

Features:

- LLM integration
- Conversation memory
- Intent detection
- Tool calling
- Context understanding

---

## Phase 6 — Agent

Features:

- Planner
- Tool execution
- Filesystem
- Terminal
- Browser
- Application control
- UI automation
- Error recovery
- Confirmation system

---

## Phase 7 — Coding Agent

Features:

- Repository understanding
- Code editing
- Terminal
- Test execution
- Git
- Debugging
- Integration with external coding agents

---

# 28. Example Future Interaction

### Scenario 1 — Gesture

User moves index finger.

```text
Camera
 ↓
Hand Tracking
 ↓
Index Finger
 ↓
Cursor
```

User pinches.

```text
Pinch
 ↓
Left Click
```

---

### Scenario 2 — Voice

User:

> "KAI, turn the volume down."

KAI:

```text
Speech
 ↓
Intent
 ↓
Volume Tool
 ↓
macOS
 ↓
"Volume decreased."
```

---

### Scenario 3 — Agent

User:

> "KAI, check my project and tell me why the API is failing."

KAI:

```text
Understand request
       ↓
Open project
       ↓
Inspect files
       ↓
Inspect logs
       ↓
Analyze code
       ↓
Identify issue
       ↓
Explain result
```

---

### Scenario 4 — Autonomous Coding

User:

> "KAI, fix it."

KAI:

```text
Understand
   ↓
Plan
   ↓
Edit
   ↓
Run tests
   ↓
Observe
   ↓
Fix if needed
   ↓
Run tests again
   ↓
Report
```

---

# 29. Important Engineering Principles

## 29.1 Modular

Every subsystem should be replaceable.

For example:

```text
VisionProvider
LLMProvider
SpeechProvider
AgentProvider
```

should use protocols/interfaces.

---

## 29.2 Model Agnostic

Do not tightly couple KAI to one AI provider.

Possible providers:

```text
OpenAI
Anthropic
Google
Local Models
Other Providers
```

The user should eventually be able to select the provider.

---

## 29.3 Agent Safety

Never allow an LLM to directly execute arbitrary system operations without going through KAI's permission and tool layers.

Architecture:

```text
LLM
 ↓
Tool Request
 ↓
Permission / Policy
 ↓
Confirmation if required
 ↓
Tool Executor
 ↓
macOS
```

---

## 29.4 Event Driven

Use events between subsystems.

Example:

```text
GestureDetected
VoiceCommandReceived
ApplicationChanged
AgentActionRequested
ToolExecutionCompleted
```

This will make the system easier to extend.

---

# 30. Future Possibilities

KAI could eventually support:

- Multi-monitor control
- Apple Vision Pro
- iPhone as remote input
- iPad
- Smart home control
- Calendar
- Email
- Browser automation
- Meeting assistant
- Screen understanding
- Personal knowledge base
- Local memory
- Coding assistant
- Research assistant
- Workflow automation
- Custom plugins

Eventually:

```text
KAI
│
├── Mac
├── iPhone
├── iPad
├── Vision Pro
├── Smart Home
└── Cloud Services
```

---

# 31. Ultimate Vision

The ultimate goal is not to build another mouse.

The goal is to build:

> **A personal AI layer for the computer.**

Traditional UI:

```text
Click
Type
Search
Navigate
Repeat
```

KAI:

```text
Tell KAI what you want.
KAI understands.
KAI plans.
KAI acts.
KAI tells you what happened.
```

The long-term experience should feel like:

```text
Human
   ↕
KAI
   ↕
Computer
```

rather than:

```text
Human
   ↓
Keyboard
   ↓
Mouse
   ↓
Menus
   ↓
Applications
```

---

# 32. Product Statement

**KAI is an AI companion for macOS that combines vision, voice, gestures, contextual intelligence, and autonomous agents to create a more natural way to interact with computers.**

> **KAI — See. Hear. Think. Act.**
