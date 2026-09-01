# EDGE-033 · streaming L3 ledger/alarm re-audit · 2026-08-30

The `judge.py` L3 pass for `关页不留 streaming 孤儿` was written only after the same sealed
session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-152501` was re-opened and
its frame, backend, three SSE, frontend, and managed LLM evidence was read together.

`alarms.py check` then opened `gap-too-fast` and `discovery-collapse`. These were not silently
ignored: the gap curve was caused by the historical journal's compressed timestamps, and the
discovery curve covered one independently reviewed A5 product behavior, not a bulk batch. The
25-second and 5-percent thresholds were not changed. Both alarms were acknowledged with notes
bound to the new judgment waterline, and a subsequent `alarms.py check` returned clean.
