# EDGE-079 · 恢复后排队戳是新起点

## Verification

After a crash gap, the recovering walk creates a fresh `ready_at` for the node that had not yet
been scheduled. The stamp is at or after the recovery walk, never backdated to the original run
creation time; this makes queue latency honest instead of presenting a fake seamless continuation.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestStamps_RecoveryIsANewQueueStart$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestStamps_RecoveryIsANewQueueStart$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

## Five-level applicability

- L1 pass: the recovered node's `ready_at` is at or after the recovery walk and is not backdated to run creation.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
