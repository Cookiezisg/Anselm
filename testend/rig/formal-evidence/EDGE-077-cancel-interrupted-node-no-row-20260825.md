# EDGE-077 · 被打断的在飞节点不落行

## Verification

Cancelling a run while an agent is blocked in its provider call interrupts the registered advance
context. The interrupted node writes no `flowrun_nodes` row and is not misreported as `failed`; the
run becomes `cancelled`, and the scheduler remains usable for a subsequent run. The same behavior
is exercised through the black-box flowrun API with a stalled fake provider.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestCancelRun_InterruptsBlockedAgent_NoRowForInterruptedNode$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestCancelRun_InterruptsBlockedAgent_NoRowForInterruptedNode$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

cd testend
mise exec -- go test ./scenarios \
  -run '^TestFlowrun_CancelInFlightAgent$' -count=1
ok  github.com/sunweilin/anselm/testend/scenarios
```

## Five-level applicability

- L1 pass: cancellation interrupts the in-flight node without a durable node row or false failure, then the scheduler accepts a later run.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
