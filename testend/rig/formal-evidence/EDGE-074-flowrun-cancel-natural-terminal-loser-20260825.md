# EDGE-074 · run 取消竞态输家

## Verification

The deterministic run-store seam makes the real first-wins race reproducible: a natural terminal
transition wins immediately before `CancelRun`'s guarded transition. The cancel path returns
`FLOWRUN_NOT_CANCELLABLE`, preserves the natural failed header, leaves the replayable parked row
untouched, and emits no second `run_terminal`. The existing black-box cancel path also confirms the
normal running-to-cancelled HTTP contract and post-terminal guard.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestCancelRun_GuardLoserLeavesNaturalTerminalAlone$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestCancelRun_GuardLoserLeavesNaturalTerminalAlone$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

cd testend
mise exec -- go test ./scenarios \
  -run '^TestFlowrun_CancelParkedRun$' -count=1
ok  github.com/sunweilin/anselm/testend/scenarios
```

## Five-level applicability

- L1 pass: the natural-terminal guard loser returns the stable not-cancellable error, preserves durable state, leaves the parked row, and emits no duplicate terminal frame.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
