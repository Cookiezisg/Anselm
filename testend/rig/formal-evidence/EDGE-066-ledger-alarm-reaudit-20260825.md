# EDGE-066 · ledger/alarm re-audit

The five EDGE-066 judgments followed the high-frequency inbox test, ordinary and race-focused
coverage, the pool regressions, and the complete scheduler package. The unchanged statistical
alarms opened during the serialized ledger write, were reviewed against the evidence, and were
acknowledged without changing thresholds, CODEX laws, anchors, or gate policy.

```text
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-066 evidence
alarms.py check         -> clean (516 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 563 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
