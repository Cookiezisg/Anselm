# EDGE-305 L5 账本与警报独立复审

- target: `EDGE-305|侧幕尊重手动关`
- judgment: L5 `G1`
- anchor set: `10/10`
- formal session: `20260901-162006`
- final alarm state: `clean (314 live judgments; 4240 baseline judgments excluded from drift curves)`

## Evidence check

- L5 evidence is a non-empty formal record with a sealed real-App recording, Computer Use frames, backend journal, three-stream SSE journal, frontend console journal, and LLM wire journal.
- The judgment cites `G1` in `CODEX.md`; no pass was entered without evidence and no level was waived.
- The known macOS `IMKCFRunLoopWakeUpReliable` host diagnostic was not reclassified as a Flutter/Dart/RenderFlex/Unhandled clean result.

## Alarm disposition

- `discovery-collapse`: re-audited against the visible X entry, retained Toggle, second-activity no-reopen behavior, sealed recording, and five-channel journals after fresh `10/10` anchor calibration.
- The zero-failure window is evidence-backed, not a blind rubber stamp; the alarm was acknowledged without changing its threshold.
- No law, anchor, five-level standard, batch gate, or alarm threshold was weakened.

## Result

`alarms.py check` is clean. `gen_coverage.py --check` reports `848 rows, 848 carried judgments, 0 tombstones`; the live ledger now has `784/848` fully settled rows and `4053` settled cells.
