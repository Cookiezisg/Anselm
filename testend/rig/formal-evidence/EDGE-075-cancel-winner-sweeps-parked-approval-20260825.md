# EDGE-075 · 取消赢家收割 parked 审批

## Verification

When a running flowrun is parked on approval and the cancel transition wins the durable header
guard, `CancelParkedNodes` settles only that parked node as `cancelled`. The inbox is empty, the
run and node agree on the terminal disposition, and no false `failed` row is created. The same
contract is verified through the real HTTP flowrun cancel endpoint.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestCancelRun_ParkedRun_SweepsInboxAndSettlesDrain$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestCancelRun_ParkedRun_SweepsInboxAndSettlesDrain$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

cd testend
mise exec -- go test ./scenarios \
  -run '^TestFlowrun_CancelParkedRun$' -count=1
ok  github.com/sunweilin/anselm/testend/scenarios
```

## Five-level applicability

- L1 pass: the winning cancel settles the parked node as `cancelled`, removes it from the inbox, and emits the matching terminal state without a false failure.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
