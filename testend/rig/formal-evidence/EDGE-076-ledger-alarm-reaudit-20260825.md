# EDGE-076 · ledger/alarm re-audit

The five EDGE-076 judgments followed the guard-loser parked-subgraph regression in ordinary and
race modes. The unchanged statistical alarms opened during the serialized ledger writes, were
reviewed against the evidence, and were acknowledged without changing thresholds, CODEX laws,
anchors, or gate policy.

```text
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-076 evidence
alarms.py check         -> clean (566 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 573 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```

The row is `L1=measure:edge076-cancel-loser-must-not-sweep-parked-subgraph` and `L2-L5=na`; no
App, frame-timing, visual, or discoverability evidence was invented.
