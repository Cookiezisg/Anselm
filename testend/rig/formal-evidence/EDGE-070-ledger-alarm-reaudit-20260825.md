# EDGE-070 · ledger/alarm re-audit

The five EDGE-070 judgments followed the approval first-wins regression, its race run, and the
complete scheduler package. The unchanged statistical alarms opened during the serialized ledger
write, were reviewed against the evidence, and were acknowledged without changing thresholds,
CODEX laws, anchors, or gate policy.

```
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-070 evidence
alarms.py check         -> clean (536 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 567 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
