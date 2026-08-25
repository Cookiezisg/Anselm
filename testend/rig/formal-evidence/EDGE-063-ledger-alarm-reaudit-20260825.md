# EDGE-063 · ledger/alarm re-audit

The five EDGE-063 judgments followed the ordinary, race, and complete scheduler tests. The
existing statistical alarms were allowed to open under their unchanged thresholds, then reviewed
and acknowledged independently. No threshold, algorithm, CODEX law, anchor, or gate policy changed.

```text
alarms.py check         -> expected gap-too-fast and discovery-collapse alarms opened
alarms.py ack ...       -> both acknowledged against EDGE-063 evidence
alarms.py check         -> clean
gen_coverage.py --check -> 848 rows / 560 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
