# EDGE-077 · ledger/alarm re-audit

The five EDGE-077 judgments followed the interrupted-node regression in ordinary and race modes
plus the black-box stalled-agent cancellation. The unchanged statistical alarms opened during the
serialized ledger writes, were reviewed against the evidence, and were acknowledged without
changing thresholds, CODEX laws, anchors, or gate policy.

```text
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-077 evidence
alarms.py check         -> clean (571 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 574 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```

The row is `L1=measure:edge077-cancel-interrupted-node-no-row` and `L2-L5=na`; no App,
frame-timing, visual, or discoverability evidence was invented.
