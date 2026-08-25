# EDGE-070 · approval 人工 vs 超时 first-wins

## Verification

A parked approval is resolved concurrently by a human YES and the timeout sweep. The durable
conditional update admits exactly one winner; the loser is a clean ErrNodeNotParked, the run
settles once, and the downstream branch matches the recorded decision. A later decision is also
rejected, so no second write can corrupt the node.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestApproval_HumanVsTimeoutFirstWinsRace$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestApproval_HumanVsTimeoutFirstWinsRace$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

## Five-level applicability

- L1 pass: concurrent first-wins, clean loser, one terminal decision, consistent downstream routing, and late-decision rejection are asserted.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
