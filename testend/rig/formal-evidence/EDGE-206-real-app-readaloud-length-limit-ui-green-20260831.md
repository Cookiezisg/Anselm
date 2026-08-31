# EDGE-206 · real App read-aloud length limit UI after fix

## Result

GREEN for the post-fix real App treatment of an over-limit read-aloud action. The same
conversation containing `4001` CJK runes was opened in the rebuilt macOS App. The visible
speaker affordance remains present, but its accessibility label and tooltip explain the
constraint in user language: `Too long to read aloud in one go (maximum 4,000 characters)`.
The action is disabled, so the user gets an immediate explanation instead of a vague failure
toast or a request that cannot succeed.

This is the follow-up to the initial API-boundary session, which intentionally left L4/L5 open
because the old App showed only `Read-aloud failed`. That red observation is retained in
`EDGE-206-real-app-readaloud-length-limit-green.md`; this document records the implemented fix
and its real-App recheck.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-100536`

Real upstream: `https://api.anselm.website`; workspace `ws_369e8aee2eb9de9d`.

## Controlled sequence

The conductor launched the rebuilt App against the real local sidecar and attached all five
observers. Computer Use opened the existing `EDGE-206 长文本朗读边界` conversation. The user
message visibly contains the over-limit CJK payload, and the AX tree exposed:

```text
25 button (settable) Too long to read aloud in one go (maximum 4,000 characters)
```

The same element stayed unchanged after a Computer Use click attempt: no generic error toast,
no playback control, and no new read-aloud request were produced. The screenshot captured from
the post-fix App shows the disabled speaker affordance aligned with the other message actions;
the finalized `screen.mov` is the durable frame record.

## Five-channel evidence

- **Frame**: `screen.mov` is finalized (`156.288333s`). The real App shows the long user message,
  the explanatory speaker tooltip/label, a settled assistant answer, and a usable composer. The
  post-fix AX state is included above; the click attempt produces no UI error surface.
- **Backend**: `backend.log` records the healthy sidecar and the real App capability probe. It
  contains no read-aloud request after the disabled-action click, no application ERROR, and no
  panic.
- **SSE**: `sse.jsonl` records all three stream connections and their clean disconnect. No chat
  turn or durable read-aloud event is created by the disabled action.
- **Frontend console**: `frontend.log` contains no Flutter/Dart application exception, layout
  overflow, or unhandled error. The only matching diagnostic is the known macOS IMK message.
- **LLM wire**: `llm.jsonl` contains only the tap readiness record for this recheck and no
  `/v1/audio/speech` request. The UI therefore does not spend an upstream speech request on a
  deterministically impossible input.

## Measurement and judgement

The shared frontend constant `readAloudMaxRunes = 4000` is used to classify the same boundary
that the backend enforces. The widget regression verifies that a `4001`-rune turn exposes the
localized explanatory label, disables the action, and does not call the read-aloud source.
The real App recheck proves the same treatment survives the compiled macOS surface and the
five-channel rig.

L4 uses `C4`: the action geometry remains aligned and the explanatory state is legible without
an abrupt toast or a broken control. L5 uses `G1`: the visible action tells a user what is
unavailable and why, without requiring knowledge of the API error code.
