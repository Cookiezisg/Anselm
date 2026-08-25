# EDGE-075 · ledger/alarm re-audit

The five EDGE-075 judgments followed the winner-only parked-node sweep regression in ordinary and
race modes plus the black-box cancel contract. The unchanged statistical alarms opened during the
serialized ledger writes, were reviewed against the evidence, and were acknowledged without
changing thresholds, CODEX laws, anchors, or gate policy.

```text
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-075 evidence
alarms.py check         -> clean (561 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 572 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```

The row is `L1=measure:edge075-cancel-winner-sweeps-parked-approval` and `L2-L5=na`; no App,
frame-timing, visual, or discoverability evidence was invented.
