# EDGE-074 · ledger/alarm re-audit

The five EDGE-074 judgments followed the deterministic cancel-vs-natural-terminal race, its race
build, and the black-box cancel contract. The unchanged statistical alarms opened during the
serialized ledger writes, were reviewed against the evidence, and were acknowledged without
changing thresholds, CODEX laws, anchors, or gate policy.

```text
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-074 evidence
alarms.py check         -> clean (556 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 571 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```

The row is `L1=measure:edge074-flowrun-cancel-natural-terminal-loser` and `L2-L5=na`; no App,
frame-timing, visual, or discoverability evidence was invented.
