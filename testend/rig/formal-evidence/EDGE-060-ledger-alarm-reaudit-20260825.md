# EDGE-060 · ledger/alarm re-audit

The five judgments for EDGE-060 were written only after the focused frontend suite passed.
The normal statistical alarm behavior was then exercised and reviewed without changing any
threshold, algorithm, CODEX law, anchor, or gate policy:

```text
alarms.py check       -> opens the expected gap-too-fast and discovery-collapse alarms
alarms.py ack ...     -> both alarms acknowledged with this row's evidence pointer
alarms.py check       -> clean
gen_coverage.py --check -> 848 rows / 557 carried judgments / 0 tombstones
anchors.py check      -> 10/10
```

The final clean state is the only state accepted for the next frontier.

