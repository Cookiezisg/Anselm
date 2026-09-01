# EDGE-308 侧幕失败行清除：L4 真实 App 视觉证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-174601`
- data: `/private/tmp/anselm-data-edge308-l4-real-20260901`
- workspace: `ws_933489bb992e4c3e`
- function: `fn_7f64265c79c6b745`, active version `fnv_1ed19ad6c206ce30`
- conversation: `cv_69918bee47434cb6`
- recording: `screen.mov`, 3104x1844, 60fps, 153.206667s
- frame samples: `evidence/EDGE-308-l4-t65.png`, `evidence/EDGE-308-l4-t75.png`, `evidence/EDGE-308-l4-t120.png`
- interaction witness: `testend/rig/formal-evidence/EDGE-308-sidestage-failure-clear-l4-ax-20260901.txt`

## Product path

1. A fresh real App conversation used the normal Chat path to run one deliberately failing Function. The fixture raised `RuntimeError("edge308 intentional failure")`; there was no second execution or retry.
2. The center transcript showed the failed tool result and traceback. The Activity island showed one touched and executed Function row, a red failure dot, `Failed`, and the actionable explanation `Run failed · inspect the error below`.
3. Moving the pointer over the failed row revealed the row-level `Clear this row` action. Clicking it removed only the failed-hold presentation: the same Activity row remained as quiet `Ran` history with no red dot, while the transcript and durable execution evidence stayed intact.

## Frame review

- `t=65s` and `t=75s` show the stable failed state: the red failure treatment is localized to the Activity row and failure ribbon; the center still exposes the technical detail needed for inspection.
- `t=120s` shows the settled post-clear state: the Activity island keeps the execution identity as `Ran`, has no red failure dot or failure ribbon, and the center transcript has not jumped or lost content.
- The Computer Use AX witness records the hover-only action and the post-click state. The action is not a destructive delete and does not alter the execution result.
- Across the sampled frames there is no duplicate row, automatic rerun, Live/Failed oscillation, or layout jump. The failure exit is local to the row and visually monotonic.

## Five-channel cross-check

- frames: the session-owned 60fps recording contains the failed state, hover interaction, clear action, and settled state; fixed frame samples are listed above.
- backend: PID `41473` owned `:8743`; `backend.log` has 478 lines and no application `panic`, `FATAL`, `WARN`, or `ERROR` redline.
- SSE: `sse.jsonl` has messages durable seq `1..23`, entities durable seq `7..10`, and notifications durable seq `16..20`; each stream is unique and monotonic. The messages stream retains the failed `run_function` call/result.
- frontend: PID `41999` and window `13455` were owned by this rig. `frontend.log` has four known macOS IMK/TSM/Dart-host lines and no Flutter, RenderFlex, Unhandled, or application runtime error.
- LLM wire: `llm.jsonl` records the managed challenge/install/models handshake and four real Chat completion requests through `llmtap` to `https://api.anselm.website`; all observed responses are HTTP `200`.
- durable truth: SQLite records exactly one `function_executions` row for `fn_7f64265c79c6b745`, status `failed`, elapsed `130ms`, with the full traceback. `message_blocks` retains the reasoning, tool call, failed tool result, progress traceback, and assistant text after the Activity clear.
- rig lifecycle: `rig-check` passed while all five channels were live; `rig-down` finalized the recording and stopped the owned App, backend, ssetap, llmtap, and recorder without residue.

## Judgment

- L4 `pass (C4)`: the failed activity is visually legible, localized, and recoverable from its only persistent failure hold. Hovering exposes a precise row-level exit; clearing it returns the row to quiet history without deleting, rerunning, or visually disturbing the underlying product truth.
- This evidence does not claim the deferred 400+ Journey expansion; it covers the real failure-activity lifecycle and its visual craft.
