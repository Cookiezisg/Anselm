# EP-161 L3 · `GET /api/v1/conversations/{id}/usage` · 真实 App

## 现场

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-000853`
- Workspace: `ws_db3955d20c6acdff`
- Conversation: `cv_4ccf5dae5abd05a3`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `172.286667s`
- Product path: Computer Use launched the real App, focused the Chat composer, entered
  `Reply with exactly OK.`, sent it, and observed the completed assistant answer `OK`.

## Product and data result

The real App completed the user-purpose path without a direct API mutation. The durable REST
message read for the same conversation contained one completed assistant message with
`inputTokens=16430` and `outputTokens=14`; the assistant close frame carried the same values.
The usage endpoint returned:

```json
{"data":{"inputTokens":16430,"outputTokens":14,"totalTokens":16444}}
```

The invariant holds exactly: `16430 + 14 = 16444`. Three independent REST probes of the endpoint
returned HTTP 200 with total times `1.402ms`, `1.039ms`, and `1.158ms` (maximum `1.402ms`), all
well below the `A1` 100ms visible-response budget.

## Cross-channel truth

- REST/SQLite: the conversation's durable message accounting and the usage aggregate agree; the
  final assistant text is exactly `OK`.
- SSE: the messages stream recorded the user open/close, assistant reasoning and text
  open/delta/close, and the completed assistant close with `inputTokens=16430` and
  `outputTokens=14`; notification stream recorded creation and auto-title signals.
- LLM wire: managed challenge and the real chat completion crossed `llmtap`; the completion
  response was HTTP 200. No mock provider was used.
- Backend: D1 attribution, health, and graceful shutdown passed; no panic, fatal, application
  error, or warning was present in the backend journal.
- Frontend: the real App rendered the completed `OK` response; no Flutter/Dart/RenderFlex/
  overflow/Unhandled error was present. The only logged line was the known macOS IMK mach-port
  diagnostic.
- `rig-check.sh` and `rig-down.sh` passed; the recording was finalized and all owned App,
  backend, SSE tap, and LLM tap processes were collected.

## Judgment

`A1` pass. This is an API-only read endpoint. It has no independent Flutter visual surface,
clickable control, or shortcut; L4/L5 therefore remain the existing applicability judgments and
are not represented as visual or discoverability passes here.
