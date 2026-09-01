# EDGE-307 poll 型 202 不谢幕：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-173833`
- data: `/private/tmp/anselm-data-edge307-l5-real-20260901`
- screen: `screen.mov`, 3104x1844, 60fps, 97.545000s
- frame samples: `evidence/EDGE-307-l5-t48.png`, `evidence/EDGE-307-l5-t55.png`, `evidence/EDGE-307-l5-t64.png`, `evidence/EDGE-307-l5-t75.png`
- workflow: `wf_5d6e08ec1349abcc`, `background_report`
- flowrun: `fr_9aeab4837fcf308d`
- fixture: `fn_4887785e7bfea2e0`, active version `fnv_09a95349daa4bd90`, deliberately sleeps 12 seconds

## Blind product path

The user supplied only this ordinary goal, with no workflow ID, internal tool name, or instruction to
open Activity: “Please run the background report and tell me when the final report is ready, not
merely queued.” The model searched for `background report`, found exactly one workflow, triggered it,
opened the run, and waited for the terminal state.

The running interval remained discoverable without diagnostic knowledge: the center showed that the
workflow had been triggered and was still running, while the right island showed one `Live` activity
with `Listening live · settle follows the truth`. After the durable terminal, the assistant clearly
said the report was ready, gave `completed`, the returned report result, the `ready` status, and the
approximately 12-second duration. The right island settled to `Ran` for the same workflow.

## Frame review

- `t=48s`: the blind user path has one visible live activity and an explicit settle explanation; there
  is no premature completion claim.
- `t=55s`: the terminal transition is visible as a single completion handoff, with the completed run
  card appearing under the same conversation.
- `t=64s` and `t=75s`: the final answer and `Ran` activity are stable across repeated frames. The
  user can identify that the report is complete, read its result, and distinguish completion from
  queueing without opening a hidden surface or decoding an ID.

## Five-channel cross-check

- frames: the window-owned recording contains the blind Live interval, terminal handoff, and stable
  final frames above.
- backend: PID `40550` owned `:8743`; backend journal has no `panic`, `FATAL`, application `WARN`,
  or `ERROR`.
- SSE: `sse.jsonl` records messages durable seq `1..31`, entities durable seq `7..12`, and
  notifications durable seq `16..22`, each unique and monotonic. The entities stream records
  `run_started`, two completed node/run signals, and `run_terminal` for `fr_9aeab4837fcf308d`.
- frontend: PID `41019` and the recorded window belong to this session. The only diagnostic is the
  known macOS IMK host message; there are no Flutter, Dart, RenderFlex, layout, or Unhandled errors.
- LLM wire: `llm.jsonl` records managed challenge/install/models and 5 chat completion requests
  through `llmtap` to `https://api.anselm.website`; all observed responses are HTTP `200`.
- durable truth: SQLite records the flowrun as `completed`, `origin=chat`, with `entry` and `report`
  both `completed`; the report result is `{"message":"Your background report is ready.","report":"ready"}`.
- rig lifecycle: `rig-check` passed before teardown, `rig-down` finalized the recording, and all
  owned processes were stopped without residue.

## Judgment

- L5 `pass (G1)`: a user with only an outcome-oriented request can discover the matching workflow,
  understand the live-versus-complete distinction, and recognize the final result without knowing
  internal IDs, tool names, or the Activity panel in advance.
- This evidence does not claim the deferred 400+ Journey expansion; it covers the discoverability of
  this poll-style execution outcome.
