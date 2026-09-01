# EDGE-033 · 关页不留 streaming 孤儿 · real App session 20260830

## Scenario

在真实 macOS App 中新建对话，发送一条会触发多步 streaming 的消息；assistant 已打开并
产生 reasoning/tool block 后关闭 App 窗口。验证客户端消失不会留下 durable streaming 孤儿，
后端仍能在 detached context 中完成本回合，且 SSE、LLM wire、前端日志都可对账。

Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-150746`

## Five-channel evidence

- **Frames**: `screen.mov` is a finalized 3076x1830 recording of 297.313333 seconds. The App
  shows the sent user message and an in-flight assistant state before the close. Around recording
  seconds 257.75–258.00 (wall clock about 15:12:52), the App window disappears; subsequent frames
  remain the empty desktop. Extracted keyframes are in `keyframes/transition-sheet.png`.
- **Backend journal**: POST `/messages` returns 202 at 15:12:46.834. The backend records no
  WARN/ERROR/panic/FATAL. The assistant is durably closed at 15:13:01.703737; graceful rig shutdown
  is later at 15:13:32.339.
- **SSE witness**: all `messages`, `entities`, and `notifications` streams connected. The messages
  stream records user open/close, assistant open, reasoning/tool blocks, and exactly one assistant
  close at seq 20 with `status=completed`; all three streams disconnect only during rig shutdown.
- **Frontend console**: the log contains the direct App start, normal Dart VM service startup, one
  macOS IMK diagnostic, and the expected `[backend] stop requested child=null`; it contains no
  FlutterError, DartError, RenderFlex, Unhandled, Exception, panic, or fatal line.
- **LLM wire**: the recorder captured the managed gateway challenge and three chat-completion
  requests. Every challenge/chat response is HTTP 200 and request/response bodies are retained.

## Judgement

- **L2 pass** under `F2`: the real App was closed after an assistant stream had opened and produced
  durable blocks; the backend completed the assistant close, SSE observed the paired lifecycle, and
  no streaming orphan remained.
- **L3/L4/L5 remain open**: this scenario proves lifecycle recovery, not independent timing,
  geometry/aesthetic, or discoverability quality.

