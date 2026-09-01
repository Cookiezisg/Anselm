# EDGE-304 账本与警报独立复审

- target: `EDGE-304|侧幕跟随三档`
- judgments: L4 `C4`, L5 `G1`
- anchor set: `10/10`
- formal sessions: `20260901-155611` (L4), `20260901-160554` (L5)
- final alarm state: `clean (312 live judgments; 4240 baseline judgments excluded from drift curves)`

## Evidence check

- L4 evidence is a non-empty formal record with a sealed real-App recording, Computer Use frame, backend journal, three-stream SSE journal, frontend console journal, and LLM wire journal.
- L5 evidence is a non-empty formal record with a sealed real-App recording, Computer Use frame, backend journal, three-stream SSE journal, frontend console journal, and LLM wire journal.
- Both judgments cite laws present in `CODEX.md`; no `pass` was entered without evidence and no `na` was used to bypass the product levels.
- The frontend error lines are the known macOS `IMKCFRunLoopWakeUpReliable` host diagnostic only; no Flutter/Dart/RenderFlex/Unhandled error was reclassified as clean.

## Alarm disposition

- `gap-too-fast`: re-audited against both real sessions and the fresh `10/10` anchor calibration; the judgments were evidence-backed, so the alarm was acknowledged without changing the threshold.
- `discovery-collapse`: re-audited against the ordinary-user L5 path and its five-channel evidence; zero failures did not represent a blind rubber stamp, so the alarm was acknowledged without changing the threshold.
- No law, anchor, five-level standard, batch gate, or alarm threshold was weakened.

## Result

`alarms.py check` is clean. `gen_coverage.py --check` reports `848 rows, 848 carried judgments, 0 tombstones`; the live ledger now has `784/848` fully settled rows and `4051` settled cells.
