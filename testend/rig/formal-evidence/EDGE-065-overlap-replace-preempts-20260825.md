# EDGE-065 · overlap replace 抢占

## Verification

With a running workflow already in flight, a new `replace` firing first cancels the old run
through the guarded terminal transition, then seeds and executes exactly one successor. The
cancelled run remains a neutral terminal audit row; the successor completes and dispatches its
action once. The same-batch replacement path remains covered as a sibling regression.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestFiring_OverlapReplace($|_SameBatch$)' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestFiring_OverlapReplace($|_SameBatch$)' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

The test fixture was corrected to provide the graph's required `start.orderId` input. The first
diagnostic run exposed that omission as a real failed successor, so the acceptance assertion was
not weakened; the production replace path was unchanged.

## Five-level applicability

- L1 pass: guarded cancellation, consumed firing, one cancelled predecessor, one completed successor, and one successor action are asserted.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
