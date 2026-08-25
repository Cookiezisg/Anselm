# EDGE-065 · ledger/alarm re-audit

The five EDGE-065 judgments were recorded only after the replace regression passed in ordinary,
race, and complete scheduler tests. The test fixture's missing `start.orderId` was corrected after
the first diagnostic failure; no production behavior or gate threshold was weakened. The unchanged
statistical alarms opened during the serialized ledger write, were independently reviewed against
the EDGE-065 evidence, and were acknowledged.

```text
alarms.py check         -> gap-too-fast and discovery-collapse opened
alarms.py ack ...       -> both acknowledged with EDGE-065 re-audit notes
alarms.py check         -> clean (511 live judgments; 2300 baseline excluded)
gen_coverage.py --check -> 848 rows / 562 carried judgments / 0 tombstones
anchors.py check        -> 10/10
```
