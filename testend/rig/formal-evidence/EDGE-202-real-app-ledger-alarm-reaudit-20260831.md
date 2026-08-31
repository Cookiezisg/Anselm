# EDGE-202 ledger/alarm re-audit · 2026-08-31

The four EDGE-202 judgments were written from one sealed real-App session with an explicit
`1500ms` rig TTL seam. `alarms.py check` opened `gap-too-fast` because the four cells landed in
the protected short-gap window. The alarm is a review trigger and the threshold is unchanged.

Re-audit:

- L2 is bound to `20260831-091019`; all six required session artifacts exist, the real macOS App
  launched directly, the three SSE streams connected, and `rig-check` passed before teardown.
- L3 is supported by the backend journal's first lease + `206` Range/full reads, an independent
  expired lease `404`, and a later real App lease mint with new `206` reads. The manifest records
  `playbackLeaseTtlMs=1500`; production default remains unchanged.
- L4 is supported by the final recorded audio card with duration, progress line, and play
  affordance. L5 is supported by the directly discoverable Play control and transparent re-mint
  after returning to the conversation.
- No backend ERROR/panic or frontend Flutter/Dart application exception occurred. No model or
  gateway billing call was attributed to local audio playback.
- No CODEX law, threshold, anchor set, sequence policy, or alarm algorithm changed.

This independent review supports acknowledging `gap-too-fast`; the append-only judgment history
and original provisional pointers remain intact.
