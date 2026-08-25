# EDGE-071 · ledger/alarm re-audit

The five EDGE-071 judgments followed the three-behavior timeout regression, the first-wins race
regression, and the complete scheduler package. The unchanged statistical alarms opened during the
serialized ledger write, were reviewed against the evidence, and were acknowledged without
changing thresholds, CODEX laws, anchors, or gate policy.

```
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-071 evidence
alarms.py check         -> clean (541 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 568 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
