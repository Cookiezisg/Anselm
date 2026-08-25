# EDGE-064 · ledger/alarm re-audit

The five EDGE-064 judgments followed the focused, race, store, and complete scheduler tests.
The existing statistical alarms opened under their unchanged thresholds during serialized ledger
writes, were independently reviewed, and were acknowledged. No threshold, algorithm, CODEX law,
anchor, or gate policy changed.

```text
alarms.py check         -> expected gap-too-fast and discovery-collapse alarms opened
alarms.py ack ...       -> both acknowledged against EDGE-064 evidence
alarms.py check         -> clean
gen_coverage.py --check -> 848 rows / 561 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
