# EDGE-308 侧幕失败行清除：L5 真实用户可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-175425`
- data: `/private/tmp/anselm-data-edge308-l5-real-20260901`
- workspace: `ws_f277016f4dfd6dd3`
- function: `fn_b5e19676da386531`, active version `fnv_831fbeb0fb4330c5`
- conversation: `cv_d73e8cc3f4e0ba8d`
- recording: `screen.mov`, window-owned 60fps recording; final duration is sealed by `rig-down`
- frame samples: `evidence/EDGE-308-l5-hover-clear-row.jpeg`, `evidence/EDGE-308-l5-cleared-viewed.jpeg`
- AX witness: the real App exposed `Clear this row` on hover and exposed `Viewed` after the click.

## Product path

1. A fresh real App conversation expressed an ordinary outcome-oriented goal: demonstrate recovery from a failure, inspect what happened, and remove only the visible failure notice while keeping history. The prompt named neither an internal function nor an implementation mechanism.
2. The model naturally searched the available catalog, found the single safe demonstration from its human-readable description, and ran it exactly once. The failure was visible in the center transcript and the Activity island automatically opened with `Failed`, a red dot, and `Run failed · inspect the error below`.
3. The model began an unnecessary second branch into execution-history inspection. The test stopped that branch before another run could occur; this is recorded as test control, not presented as model completion. The product UI itself then provided the intended user path: hover the failed row, discover `Clear this row`, and click it.
4. After clearing, the Activity row became quiet `Viewed` history. The center transcript still contained the failed tool result, traceback, and assistant explanation, and SQLite still contained the one failed execution. No data was deleted and no execution was repeated.

## Discoverability judgment

- `G1` pass: a new user who wants to remove a visible failure notice can see the red failure state and its plain-language explanation, then discover the row-level clear affordance by moving over the failed row. The affordance is exposed in the real AX tree as `Clear this row`, and the result is explicit `Viewed` rather than a disappearing or ambiguous row.
- The action is local and reversible at the presentation layer: it changes only the Activity failure hold. The durable history remains available in the center and in execution history.
- The model's stopped exploratory branch is not claimed as a successful assistant instruction path. This L5 verdict is specifically about the product UI's discoverability and honest post-action state.

## Five-channel cross-check

- frames: the session-owned recording and the two saved Computer Use screenshots cover the failure row, hover affordance, and post-clear `Viewed` state.
- backend: PID `42503` owned `:8743`; `backend.log` has 469 lines and no application `panic`, `FATAL`, `WARN`, or `ERROR` redline.
- SSE: `sse.jsonl` has 260 lines; messages, entities, and notifications all connected with unique monotonic durable sequences. The messages stream retains the failed tool call/result and the history lookup.
- frontend: PID `42996` and window `13475` were owned by this rig. `frontend.log` has only known macOS IMK/TSM/Dart-host diagnostics and no Flutter, Dart, RenderFlex, Unhandled, or application runtime error.
- LLM wire: `llm.jsonl` records the managed challenge/install/models handshake and real Chat completion requests through `llmtap` to `https://api.anselm.website`; every observed response was HTTP `200`.
- durable truth: SQLite records exactly one `function_executions` row for `fn_b5e19676da386531`, status `failed`, elapsed `119ms`, with the full traceback. Message blocks retain the failure and the history result after the Activity row was cleared.
- rig lifecycle: `rig-check` passed with all five channels physically observing; `rig-down` finalized the recording and reclaimed all owned processes.

## Judgment

- L5 `pass (G1)`: the visible failure state explains itself, the row-level exit is discoverable through the normal hover affordance, and the post-clear state honestly preserves the execution history. No internal API knowledge is required to perform the UI action.
- This evidence does not claim the deferred 400+ Journey expansion; it covers the real failure-activity recovery surface and its user discoverability.
