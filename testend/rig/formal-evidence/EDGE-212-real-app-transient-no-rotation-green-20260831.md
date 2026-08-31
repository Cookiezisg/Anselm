# EDGE-212 · real App transient failure does not rotate managed install

## Result

GREEN after the stop-and-fix from `EDGE-212-real-app-transient-copy-red-20260831.md`.
The real App received one injected managed-gateway `GET /v1/quota -> 429`, showed a
transient retry message that explicitly preserved the existing registration, and the
Repair action recovered the quota without issuing an install request or changing the
managed install identity.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-103415`

Real upstream behind the recording tap: `https://api.anselm.website`; workspace
`ws_369e8aee2eb9de9d`; managed key row `aki_986822a0998362bd`; masked install
`ins_f83...6d35`; local recording endpoint `http://127.0.0.1:8805/v1`.

## Controlled sequence

The existing managed row was reused (`RIG_SEED=0`). The tap injected exactly one
`GET /v1/quota -> 429` and then forwarded the real upstream responses. Computer Use
opened Models & keys and captured `evidence/edge212-quota-error-after-rebuild.png`.
The corrected copy was:

> Couldn't read the free-tier quota right now. Your existing device registration was left untouched; try again.

Computer Use clicked the visible `Repair free tier` CTA. The settled frame
`evidence/edge212-quota-recovered-after-repair.png` shows `12 / 1B · resets 2026-09-01
00:00` and the same masked managed install. The repair was understandable and did not
require the user to re-enter a credential or infer whether the install had rotated.

## Five-channel evidence

- **Frame**: the pre-repair frame presents a concise transient-failure explanation and
  visible retry CTA; the post-repair frame presents the quota meter and unchanged managed
  row. No duplicate card, stale error, or layout overflow is visible.
- **Backend**: `backend.log` records quota `429`, then
  `POST /api/v1/freetier:provision -> 200` and quota `200`; no panic, ERROR, or fatal
  application event is present.
- **SSE**: `sse.jsonl` records all three streams connected for the workspace and cleanly
  disconnected at teardown. This settings-only path creates no message event to invent.
- **Frontend console**: `frontend.log` contains no Flutter/Dart exception, RenderFlex
  overflow, or unhandled application error; only the known macOS IMK host diagnostic is
  present.
- **LLM wire**: `llm.jsonl` records challenge `200`, the single injected quota `429`,
  models `200`, and quota `200`. There is no `/v1/install` request. The backend and tap
  journals therefore agree that the existing install was not rotated.

## Stop-and-fix verification

The original copy incorrectly implied that a transient failure meant the installation
was revoked and that Repair would re-register it. The frontend now classifies transport,
408, 429, and 5xx failures as transient and uses the retry-preserving copy; 401/auth
failures retain the revoked-install repair explanation. Focused contract and widget
tests pass, including the 429/5xx distinction and the existing 401 path.

## Judgement

L2 uses `F2`: the visible UI, backend journal, SSE connection record, and managed wire
all agree on the transient failure and non-rotation outcome.

L3 uses `A4`: the error is immediately actionable through a visible Repair CTA and the
recovery settles without duplicate requests or an unexplained credential step.

L4 uses `C4`: the error and recovered states have stable hierarchy, readable copy, and
no layout residue; the managed identity remains legible in the same card position.

L5 uses `G1`: a user can understand that a temporary quota read failure is safe to retry
without knowing install IDs, gateway behavior, or proof transport details.
