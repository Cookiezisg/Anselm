# EDGE-307 poll 型 202 不谢幕：L4 真实 App 视觉证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-172700`
- data: `/private/tmp/anselm-data-edge307-l4-real-20260901`
- screen: `screen.mov`, 3104x1844, 60fps, 249.220000s
- frame samples: `evidence/EDGE-307-l4-t170.png`, `evidence/EDGE-307-l4-t186.png`, `evidence/EDGE-307-l4-t196.png`, `evidence/EDGE-307-l4-t210.png`
- workflow: `wf_2972480f350873bd`, `edge307_poll_202_l4`
- flowrun: `fr_486a35b8608a8412`
- fixture: `fn_39d73fb393320634`, active version `fnv_cc79aa7000c944c6`, deliberately sleeps 12 seconds

## Product path

1. A fresh real App conversation used an ordinary user goal: run the workflow and wait for the actual result. The prompt did not name an internal tool or instruct the model to open Activity.
2. The model searched the workflow by the discoverable token `edge307`, found exactly one result, and invoked it through the normal chat path.
3. The action function deliberately held the run open for approximately 12 seconds. During that window the center kept the triggering activity visible and the right island showed the same workflow row as `Live` with `Listening live · settle follows the truth`.
4. Only after the durable `run_terminal` signal did the row become `Ran`. The final answer then showed `completed`, both nodes, the returned probe value, and an approximately 12-second duration.

## Frame review

- `t=170s`: the running state is a stable composition: one user bubble, one workflow activity row, and one right-island `Live` row. The stage does not falsely announce completion while the action is still running.
- `t=186s`: the terminal transition has completed. The right island is `Ran`, the center has a single completed result card, and the activity surface has no second open/close cycle or stale live row.
- `t=196s` and `t=210s`: repeated settled frames are visually identical apart from normal clock/window timing. The table has even row geometry, the result is readable, and no Live/Running residue or non-user viewport jump remains.
- The centered result card and the right activity island agree on the same workflow. The user can understand both what happened and where the execution landed without opening a hidden diagnostic surface.

## Five-channel cross-check

- frames: the window-owned 60fps recording contains the live interval, terminal transition, and repeated settled frames above.
- backend: PID `39451` owned `:8743`; backend journal has no `panic`, `FATAL`, application `WARN`, or `ERROR`.
- SSE: `sse.jsonl` records messages durable seq `1..49`, entities durable seq `7..12`, and notifications durable seq `16..24`, each unique and monotonic. The workflow stream records `run_started`, the completed `slow` node, and `run_terminal` for `fr_486a35b8608a8412`.
- frontend: PID `40005` and the recorded window belong to this session. The only frontend diagnostics are the known macOS IMK/TSM host messages; there are no Flutter, Dart, RenderFlex, layout, or Unhandled errors.
- LLM wire: `llm.jsonl` records the managed challenge/install/models handshake and 9 chat completion requests through `llmtap` to `https://api.anselm.website`; all observed responses are HTTP `200`.
- durable truth: SQLite records flowrun `fr_486a35b8608a8412` as `completed`, `origin=chat`, with `entry` and `slow` both `completed`; `slow.result` is `{"probe":"edge307-l4-complete"}`.
- rig lifecycle: `rig-check` passed before teardown, `rig-down` finalized the recording, and all owned processes were stopped without residue.

## Judgment

- L4 `pass (C4)`: the poll-style 202 lifecycle uses a single consistent visual state for the entire asynchronous interval and one monotonic terminal transition. The Activity row does not say `Ran` before durable completion, and completion does not leave a Live ghost, duplicate card, or layout jump.
- This evidence does not claim the deferred 400+ Journey expansion; it covers the product execution lifecycle and its visual craft for this edge path.
