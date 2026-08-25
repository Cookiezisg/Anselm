# EDGE-062 · ledger/alarm re-audit

The five EDGE-062 judgments followed the focused, race, and full scheduler tests. Existing alarm
curves opened under their unchanged thresholds during serialized ledger writes; both were
independently reviewed and acknowledged. No threshold, algorithm, CODEX law, anchor, or gate
policy changed.

```text
alarms.py check         -> expected gap-too-fast and discovery-collapse alarms opened
alarms.py ack ...       -> both acknowledged with the EDGE-062 evidence boundary
alarms.py check         -> clean
gen_coverage.py --check -> 848 rows / 559 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
