# EDGE-067 · ledger/alarm re-audit

The five EDGE-067 judgments followed the manual-entry scheduler regression, its race run, the
trigger_workflow contract tests, and the complete scheduler package. The unchanged statistical
alarms opened during the serialized ledger write, were reviewed against the evidence, and were
acknowledged without changing thresholds, CODEX laws, anchors, or gate policy.

```
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged against EDGE-067 evidence
alarms.py check         -> clean (521 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 564 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
