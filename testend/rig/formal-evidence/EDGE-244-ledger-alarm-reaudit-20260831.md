# EDGE-244 ledger/alarm re-audit

- Re-audit target: the L2 judgment for `EDGE|bearer token 缺失`, written at the
  current ledger watermark, using the sealed real-App session
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-173413`.
- The re-audit re-read the session manifest, finalized `screen.mov`, backend
  journal, three-stream SSE journal, frontend console, LLM tap journal and the
  `rig-check`/`rig-down` result. The L2 evidence is therefore independently
  tied to one five-channel session, not inferred from the ledger row.
- `gap-too-fast` opened because the four-level ledger write sequence was faster
  than its statistical opening position. This is a review-speed signal, not a
  reason to change the 25-second threshold; the session evidence was actually
  re-read before acknowledgement.
- `discovery-collapse` opened because the trailing window contained no fail
  verdicts. This session is a repaired product-positive path, but the alarm is
  still acknowledged explicitly rather than hidden or weakening the fail-share
  floor.
- Anchors remain `10/10`; `gen_coverage.py --check` remains `848 rows, 848
  carried judgments, 0 tombstones`. No threshold, alarm algorithm, CODEX law,
  anchor set, five-level standard or formal sequence changed.
- The final alarm check is clean after the two serialized acknowledgements.
  The next formal atom remains `EDGE|bearer token 缺失` L3; L3-L5 are not
  promoted by this re-audit.
