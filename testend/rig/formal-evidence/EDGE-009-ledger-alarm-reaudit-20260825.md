# EDGE-009 ledger/alarm re-audit · 2026-08-25

## Trigger

The five EDGE-009 judgments opened `gap-too-fast` and `discovery-collapse`. No pass-burst alarm
opened. No detector, threshold, CODEX law, anchor, or sequence rule was bypassed or changed.

## Evidence review

- Re-read `EDGE-009-chat-turn-wall-clock-stop-fix-20260825.md`. The red finding was a real semantic
  product defect: a system wall-clock deadline was indistinguishable from a user cancellation.
- Re-ran the chat wall-clock regression and the shared loop/agent/subagent suites. Chat now records
  `error/CHAT_TURN_TIMEOUT` with actionable detail; explicit Cancel and non-chat hosts retain their
  historical cancellation semantics.
- Re-ran the focused transcript regression and frontend analyzer. The timeout copy is localized and
  raw `CHAT_TURN_TIMEOUT` / `context deadline exceeded` detail is absent from the user line.
- L1 and L4 are backed by the changed terminal contract and actual transcript widget regression.
  L2/L3/L5 remain explicit `na`: the injected stall is not claimed as a real gateway session, no
  real frame/timing capture exists for it, and the boundary is not user-navigable.
- Error-code, loop, chat-domain, and frontend generated-locale documentation were synchronized.

## Resolution

This was a genuine product semantic stop-and-fix with bounded verification, not a rubber-stamp
pass. Acknowledge the two alarms for this interval only and leave all detectors active.
