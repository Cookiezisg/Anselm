# EDGE-080 · :replay 只收 failed

## Verification

Replay accepts only a durable `failed` run. A cancelled run is terminal-final: the scheduler
returns `FLOWRUN_NOT_REPLAYABLE` without clearing nodes, reopening the header, or creating another
execution. The black-box flowrun contract confirms the same stable HTTP 422 after a real cancel.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestCancelRun_NotRunning422$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestCancelRun_NotRunning422$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

cd testend
mise exec -- go test ./scenarios \
  -run '^TestFlowrun_CancelParkedRun$' -count=1
ok  github.com/sunweilin/anselm/testend/scenarios
```

## Five-level applicability

- L1 pass: cancelled flowruns are rejected by replay with stable `FLOWRUN_NOT_REPLAYABLE` and no state mutation.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
