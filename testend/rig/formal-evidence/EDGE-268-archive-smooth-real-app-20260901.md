# EDGE-268 L3 · 驻地分组批量归档重跑 · 真实 App

## 现场

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-235910`
- Workspace: `ws_db3955d20c6acdff`
- Workdir group: `/private/tmp/anselm-edge268-l3`
- Conversations: `cv_03ccc045675449b7`, `cv_0178fd7eae3a4bab`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `112.430s`
- Product action: Computer Use opened the real group menu, opened the confirmation dialog, and clicked
  `Archive all`; no direct API call was used for the product mutation.

## Product result

The confirmation state clearly reported that two conversations would move to the archive, that they could be
brought back, and that pinned threads were left alone. After the user-confirmed action, both rows disappeared
from the active residency group in one transition and the App settled on the Recents view; the unrelated
Recents row remained. There was no blank page, duplicate row, or stale group count.

## Smoothness evidence

The recording was extracted at 30fps for the interval `[88s,103s]` into `frames-l3/`. The measurement command
was:

```text
go run ./cmd/measure diff -dir frames-l3 -threshold 0.0005
```

No diff was reported for the 223 frames before the user action. The first action feedback was detected at
frame 223 (`changedFrac=0.08205`, `box=(420,354)-(2554,1085)`), approximately `33.3ms` after the selected
action frame. The remaining changes were the single user-triggered modal/landing transition, not an
unrequested movement of existing content:

```text
f00223 -> f00224  changedFrac=0.08189  box=(420,354)-(2554,1084)
f00224 -> f00225  changedFrac=0.80825  box=(112,76)-(2992,1696)
f00225 -> f00226  changedFrac=0.73687  box=(112,76)-(2992,1696)
f00226 -> f00227  changedFrac=0.81069  box=(112,76)-(2992,1696)
f00227 -> f00228  changedFrac=0.80994  box=(112,77)-(2992,1696)
```

The inspected frames show the confirmation dialog leaving once, followed by the settled Recents state. The
large intermediate diffs are the expected dimmed-modal/landing transition caused by the explicit archive
confirmation, not a background reflow while the user was reading or typing.

## Cross-channel truth

- REST/SQLite: both target conversation rows ended with `archived=1`, `pinned=0`, and the workdir unchanged;
  target message-block count remained `0`.
- SSE: two durable notifications arrived at `2026-09-01T00:02:05.645Z`, one per target conversation, with
  `frame.node.type=conversation.archived` and `archived=true`.
- Backend: D1 port attribution passed; no panic, fatal, application error, or warning was recorded.
- Frontend: no Flutter/Dart/RenderFlex/overflow/Unhandled error; only the known macOS IMK diagnostic.
- LLM wire: managed challenge/install/models passed through the recorder; this path intentionally needed no
  chat completion.
- `rig-check.sh` and `rig-down.sh` passed; recording and all owned processes were collected.

## Judgment

`B2` pass. The App has no non-user-triggered existing-content jump in the observed archive flow; the only
visible movement is the one deliberate confirmation-to-settled transition. The exact stable-state screenshots
are `frames-l3/f00220.png`, `f00223.png`, `f00224.png`, and `f00228.png`.
