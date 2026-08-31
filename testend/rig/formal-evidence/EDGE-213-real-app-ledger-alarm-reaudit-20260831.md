# EDGE-213 · ledger/alarm independent re-audit

## Scope

The final four EDGE-213 cells opened `gap-too-fast` and `discovery-collapse`. This review
does not relax either threshold or turn the all-green result into a claim that the product
has no defects.

## Evidence audit

- Formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-104036`.
- The session contains a finalized window recording, a fresh Settings frame, backend log,
  three-stream SSE journal, frontend console journal, and managed-wire journal. `rig-check`
  passed all five observers and `rig-down` stopped all conductor-owned processes.
- The frame shows the honest unprovisioned state: `Enable free tier`, no zero-valued quota,
  no managed key row, and `Not set` defaults.
- The backend and REST records agree on the typed `FREETIER_NOT_PROVISIONED` 404. The two
  best-effort install failures were deliberately caused by the closed upstream used to hold
  the no-managed-row boundary; they were not hidden.
- The live judgment evidence is the copied session file
  `evidence/EDGE-213-real-app-quota-not-provisioned-green-20260831.md`, whose five-channel
  claims can be independently re-read from those raw files.

## Resolution

`gap-too-fast` is explained by four level writes after one complete real-App review, not by
four unobserved guesses. `discovery-collapse` is a required review signal: this narrow
honesty boundary produced no product failure in this session, but the campaign continues
to the next row and does not suppress the alarm globally. The current journal watermark is
the resolution boundary; future evidence will reopen a fresh alarm if the curves cross a
threshold again. No threshold, law, anchor, sequence rule, or verdict was changed.
