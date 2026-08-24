# SURF-092 ledger and alarm re-audit

## Scope

- Five SURF-092 cells were written serially after the repaired/static reference review and the sealed real-App session: `G1/F1/B2/C4/G1`.
- Formal journal after the writes: `2375` total = `2300` baseline + `75` live judgments.
- Coverage check before this re-audit: `848 rows / 479 carried judgments / 0 tombstones`.
- Anchor calibration was rerun from the frozen `anchor-quiz.json`: `10/10`; the anchor set and unlock window were not changed.

## Alarm review

`gap-too-fast` opened because the five ledger writes are serialized CLI calls and the recent inter-judgment median is below the statistical threshold. This is a ledger-write timing signal, not an observation-duration claim: the real App session lasted `102.840000s`, was window-bounded, and all five-channel evidence was sealed before any judgment was written. The static suite passed before the writes. No threshold or algorithm was changed.

`discovery-collapse` opened because the trailing judgment window contains no fail verdict. This is not accepted as evidence that the product is defect-free: the current cell explicitly records the eleven-kind static boundary, the real App witness, the visible compact chip decision, and the exact locale/widget regression. The evidence does not inflate one live function execution into eleven live executions.

Both alarms were independently reviewed against the raw session, final frame, investigation record, focused `12/12` locale/ref suite, anchor result and the explicit ledger boundary. They are eligible for acknowledgement without changing the gate, law, anchor set or drift thresholds.
