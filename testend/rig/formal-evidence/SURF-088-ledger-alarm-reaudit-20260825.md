# SURF-088 · ledger/alarm independent re-audit

- source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-030446`
- scope: five SURF-088 judgments; no threshold, law, anchor, or gate changes.

The final session is the third run. The first two sessions are intentionally excluded from the ledger:
`20260825-025554` caught the seeded `greet` fixture without an input declaration, and
`20260825-030052` caught traceback text leaking into the main output terminal. The source fixes were made,
focused tests passed, and the final session was rebuilt and repeated from fresh data.

The final session passed `rig-check` and `rig-down`. The recording is
`screen.mov` (`2696x1720`, H.264, 60fps, `224.743333s`). The five-channel artifacts are present:
backend journal, direct Flutter journal, independent SSE witness, real Anselm gateway LLM tap, and the
screen recording. The SSE witness connected `messages`, `notifications`, and `entities`, recorded entity
open/close frames for both the successful and deliberate failed runs, and recorded no gap. The gateway
proof challenge, install, and model catalog requests all returned HTTP 200.

The backend journal has no application `WARN`, `ERROR`, `panic`, `fatal`, or unhandled exception. The
frontend journal contains only the normal Dart VM service line and startup lines; there is no Flutter/Dart,
RenderFlex, RenderBox, or unhandled error. SQLite `integrity_check` returned `ok`, `foreign_key_check` was
empty, and the execution table contains exactly one `ok` and one deliberate `failed` execution. The
temporary failed function is soft-deleted (`DELETE` returned 204); a fresh list read returned the seeded
baseline functions, with no fixture selected or left in the visible entity list.

Product path observed in the real App:

1. The seeded `greet` function exposes the required `name: string` input and runs to `完成` with a real
   execution result.
2. A temporary function that raises `ValueError("SURF-088 deliberate failure")` reaches the failure state.
3. The primary UI presents the localized human summary `执行失败，请检查输入后重试。`, not a raw exception.
4. `技术详情` is a working disclosure: collapsed state keeps the main output clean; opening it exposes the
   selectable traceback and final exception for diagnosis; closing it restores the compact failure view.
5. Code Copy gives the localized `已复制` feedback. After REST deletion, the App re-reads the list and
   returns to the baseline without a tombstone or stale selected fixture.

The first defect was fixed by declaring the seeded `greet` input in `backend/cmd/seed/main.go`.
The second was fixed by projecting traceback tails out of the primary run terminal while retaining them in
the disclosure in `frontend/lib/features/entities/data/entity_format.dart` and
`frontend/lib/features/entities/ui/run/run_terminal.dart`. The focused regression suite passed: new
format tests `3/3`, existing run-terminal tests `8/8`; translation artifacts were regenerated with `make gen`.

Five-level admissibility:

- L1 `G1`: the path is discoverable from the entity rail; failure copy and technical-details affordance are
  understandable without reading implementation details.
- L2 `F1`: REST, SQLite, SSE close frames, and the visible success/failure/deleted states agree.
- L3 `B2`: the final recording shows no unexplained content jump, traceback flash, clipping, or overlap; the
  earlier traceback leak was corrected before this session was accepted.
- L4 `C4`: the final entity/run/error/disclosure controls follow the existing tag/button/card/island radius
  scale and remain visually stable in the recording.
- L5 `G1`: localized success, failure, technical-details, copy feedback, and cleanup affordances are
  discoverable in the real Chinese App path.

Conclusion: the five judgments are admissible. Any `gap-too-fast` or `discovery-collapse` signal caused by
the serial ledger writes must be reviewed against this record without changing its algorithm or threshold.
