# SURF-093 ledger and alarm re-audit

## Scope

- Five SURF-093 cells were written serially after the red real-App finding, source fix, regenerated i18n output, focused `11/11` suite and fresh green session: `G1/F1/B2/C4/G1`.
- Formal journal after the writes: `2380` total = `2300` baseline + `80` live judgments.
- Coverage check before this re-audit: `848 rows / 476 carried judgments / 0 tombstones`.
- Frozen anchor calibration was rerun from `anchor-quiz.json`: `10/10`; no anchor, law, threshold or gate changed.

## Alarm review

`gap-too-fast` opened because the five ledger writes are serialized CLI calls and the recent inter-judgment median is below the statistical threshold. This is a ledger-write timing signal, not an observation-duration claim: the repaired real App session lasted `46.655000s`, was window-bounded, and the five-channel evidence was sealed before any judgment was written.

`discovery-collapse` opened because the trailing judgment window contains no fail verdict. This is explicitly not treated as product evidence: SURF-093's red session found four English labels leaking into the Chinese shell after onboarding, and the source fix plus fresh rebuild removed them. The red session remains retained and excluded from green evidence.

Both alarms were independently reviewed against the red and green sessions, final frame, backend/SSE/frontend/LLM journals, focused tests, investigation record and `10/10` anchors. They are eligible for acknowledgement without changing the gate, laws, anchor set, thresholds or algorithm.
