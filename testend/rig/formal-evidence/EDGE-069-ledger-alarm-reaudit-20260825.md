# EDGE-069 · ledger/alarm re-audit

The five EDGE-069 judgments followed the injected transaction rollback test, its race run, and the
complete trigger store package. The unchanged statistical alarms opened during the serialized
ledger write, were reviewed against the evidence, and were acknowledged without changing
thresholds, CODEX laws, anchors, or gate policy.

```
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-069 evidence
alarms.py check         -> clean (531 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 566 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
