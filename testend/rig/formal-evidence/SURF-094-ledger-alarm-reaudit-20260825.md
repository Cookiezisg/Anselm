# SURF-094 ledger and alarm re-audit

## Scope

- Five SURF-094 cells are written serially after the complete bilingual action-key assertion, focused `6/6` suite, source call-site audit and fresh seeded real-App session: `G1/F1/B2/C4/G1`.
- Formal journal before these writes: `2380` total = `2300` baseline + `80` live judgments; after the five writes: `2385`.
- Coverage before these writes: `848 rows / 476 carried judgments / 0 tombstones`; after: `848 rows / 477 carried judgments / 0 tombstones`.
- Frozen anchor calibration is rerun before acknowledgement; no anchor, law, threshold or gate is changed.

## Alarm review

The expected timing and discovery alarms may open because five CLI judgments are serialized quickly and the trailing window contains no product fail verdict. They are ledger timing/statistical signals, not evidence that the real App was unobserved: the action path ran for `166.140000s`, had all five journals, and retained the Flutter AX boundary instead of hiding it.

Any opened alarms are independently reviewed against the green session, final frame, backend/SSE/frontend/LLM journals, focused tests, investigation record and `10/10` anchors, then acknowledged only with that re-audit note. Thresholds, laws, algorithms and anchors remain unchanged.
