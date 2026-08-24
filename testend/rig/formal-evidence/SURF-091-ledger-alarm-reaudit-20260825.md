# SURF-091 ledger and alarm re-audit

## Scope

- Five SURF-091 cells were written serially after the repaired real-App session:
  `G1/F1/B2/C4/G1`.
- Formal journal after the writes: `2370` total = `2300` baseline + `70` live judgments.
- Coverage check: `848 rows / 474 carried judgments / 0 tombstones`.
- Anchor calibration: `10/10`, unchanged.

## Alarm review

`gap-too-fast` opened because the five ledger writes are serialized CLI calls and the recent inter-judgment median is below the statistical threshold. This is a ledger-write timing signal, not an observation-duration claim: the real App session lasted `112.4s`, was recorded window-bounded, and the five-channel evidence was sealed before any judgment was written. No threshold or algorithm was changed.

`discovery-collapse` opened because the trailing judgment window contains no fail verdict. This is not accepted as evidence that the product is defect-free: SURF-091 itself contains a real red finding, the anonymous icon-only ocean buttons, followed by a source fix, focused regression, rebuilt App and fresh AX revalidation. The reserved coming-soon path was explicitly disclosed rather than silently counted as clicked.

Both alarms were independently reviewed against the raw session, the investigation record, the focused `35/35` suite and the anchor result. They are eligible for acknowledgement without changing the gate, law, anchor set or drift thresholds.
