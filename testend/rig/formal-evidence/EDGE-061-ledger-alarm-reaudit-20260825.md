# EDGE-061 · ledger/alarm re-audit

The five judgments for EDGE-061 were written after the 104-test boundary regression passed.
The existing alarm curves were allowed to open under their unchanged thresholds, then each was
independently reviewed and acknowledged. No threshold, algorithm, CODEX law, anchor, or gate
policy was changed.

```text
alarms.py check         -> expected drift alarms opened for the serialized five-cell write
alarms.py ack ...       -> gap-too-fast and discovery-collapse acknowledged with this evidence
alarms.py check         -> clean
gen_coverage.py --check -> 848 rows / 558 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```

