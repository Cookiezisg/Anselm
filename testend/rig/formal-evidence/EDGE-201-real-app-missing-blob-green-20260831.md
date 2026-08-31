# EDGE-201 · real App missing/unreadable blob replay

## Result

GREEN for the real replay path. The metadata row survived while its content-addressed blob was
physically removed. A real App turn containing that stale attachment and a second live text
attachment completed normally: the stale item was identified as unavailable and the live item was
read in order. No provider error or whole-turn failure was produced.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-090201`

Real upstream: `https://api.anselm.website`.
Workspace: `ws_708d055495478d4f`; conversation: `cv_f5c2aa765bea39f4`.

## Controlled input

Two real attachment rows were uploaded through the running sidecar:

```text
att_54d7979139add489  edge201-missing.txt  38b811f0f714f03683aa9677dee748427ae6440e8b3caa167d3302fcd68cdbdd
att_8017850b34eb4208  edge201-live.txt     b5c76e7d4b509c0368f7696a4abda5e42c57bb65ab6311a334727e89573c0639
```

The first blob was removed directly from its workspace blob path after upload; its metadata row
was not removed. The second blob remained readable. The real turn was sent with attachment order
`[att_54d7979139add489, att_8017850b34eb4208]`.

## Product result

The final App surface, captured in `/private/tmp/edge201-final.png` and the session recording,
showed:

```text
第一个附件 edge201-missing.txt 已不可用。
从仍可用的第二个附件 edge201-live.txt 中读到的精确内容如下：
live attachment sentinel: preserve this after the stale item
```

The stale attachment did not turn into a raw exception, and the valid attachment was not lost or
reordered. The screenshot also shows both original attachment chips, two `Read attachment`
activities, a completed assistant answer, and an available composer.

## Five-channel evidence

- **Frame**: the real macOS App recording (`136.198333s`) shows the two attachment chips, the
  unavailable-file explanation, the exact live-file content, and a normal completed state. No
  infrastructure error is exposed.
- **Backend**: `backend.log` records the expected warning for the missing blob at
  `09:03:46.094`, `09:03:55.883`, and `09:03:55.884`, with the attachment id and missing SHA;
  the turn continues. There is no ERROR or panic. The warning is explained by this deliberate
  physical deletion and is not an unexplained application failure.
- **SSE**: `sse.jsonl` records reasoning/tool activity for both attachment ids, then text close
  seq `21` and message close seq `22`, both `completed`; all three streams were connected by the
  rig.
- **Frontend console**: `frontend.log` has no Flutter/Dart application exception. It contains
  only the known macOS IMK diagnostic.
- **LLM wire**: `llm.jsonl` records two successful real gateway chat completions (`200`). The
  first response exposes the model's attachment-read result, and the second completion produces
  the final Chinese answer; no provider-level failure occurs because the stale blob was converted
  to a text note while the live attachment continued.

## Measurement and applicability

`measure:edge201-attachment-missing-blob-replay` records the durable sequence from the first
real completion request (`09:03:46.097817`) to final message close (`09:04:00.152`): the missing
blob was diagnosed during content assembly, both attachment paths remained represented, and the
turn completed in approximately `14.054s`. The screen recording was finalized by `rig-down`, and
the five-channel `rig-check` passed before teardown.

L4 is applicable and visually passed: the stale item is represented as a quiet inline explanation,
the valid item remains legible, and the composer stays available. L5 is applicable and passed:
the user can understand which attachment is unavailable and that the turn still succeeded with
the remaining attachment; no internal tool name or storage detail is required.
