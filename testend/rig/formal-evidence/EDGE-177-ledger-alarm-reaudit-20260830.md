# EDGE-177 · 账本与告警独立复审 · L2 applicability

## Re-audit scope

This re-audit covers the `EDGE|无可跑 package` L2 applicability judgment. The focused evidence
and catalog implementation establish that the formal curated marketplace exposes only entries
whose install plan has a runnable package or remote. A no-runnable package is therefore not a
user-reachable real App state; the L2 `na` is an applicability decision, not a waiver for missing
App evidence. The later L3-L5 cells remain provisional until their own sequence position is
reached and are not covered by this re-audit.

## Alarm resolution

The L2 ledger write opened `gap-too-fast` and `discovery-collapse`. The re-audit confirms that the
write used a written applicability note, did not change a pass verdict, and did not suppress the
still-open L3-L5 cells. No product failure was converted into `na`; the focused service tests,
curated-catalog invariant, and explicit product boundary are the basis for this single settled
cell.

The anchor set remains unchanged and passes `10/10`. No alarm threshold, algorithm, CODEX law,
coverage row, or formal sequence was modified. Both alarms are acknowledged only through
`alarms.py ack` with this re-audit as the resolution note.
