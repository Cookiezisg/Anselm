# EDGE-073 · ledger/alarm re-audit

The five EDGE-073 judgments followed the inbox resolve-failure regression in ordinary and race
modes. The unchanged statistical alarms opened during the serialized ledger writes, were reviewed
against the evidence, and were acknowledged without changing thresholds, CODEX laws, anchors, or
gate policy.

```text
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-073 evidence
alarms.py check         -> clean (551 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 570 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```

The row is `L1=measure:edge073-approval-version-resolve-failure` and `L2-L5=na`; no App,
frame-timing, visual, or discoverability evidence was invented.
