# EDGE-064 · overlap buffer_one 收敛

## Verification

With one run in flight and three real-trigger firings queued, `buffer_one` settles the two older
firings as `superseded` and keeps only the newest as `pending`. No action is dispatched while the
run is occupied. After the in-flight run settles, the next drain consumes the newest firing and
dispatches exactly one successor action.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestFiring_OverlapBufferOne(ConvergesToNewest|Defers)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  0.637s

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestFiring_OverlapBufferOne(ConvergesToNewest|Defers)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  1.862s

mise exec -- go test ./internal/infra/store/trigger \
  -run '^TestSupersedeAllButNewestPending$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/infra/store/trigger  0.478s

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  1.447s
```

## Five-level applicability

- L1 pass: three-fire convergence, neutral superseded rows, newest pending, and later execution are tested.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.

