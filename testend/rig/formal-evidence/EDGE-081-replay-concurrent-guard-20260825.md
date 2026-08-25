# EDGE-081 · 并发 :replay 守卫

## Verification

Two replay attempts against the same failed run cannot both reverse its terminal state. The first
reopen wins the `WHERE status='failed'` guard, reaches a new terminal, and increments
`replay_count` once; the stale second attempt returns `FLOWRUN_NOT_REPLAYABLE`, cannot resurrect the
new terminal, and cannot increment the count again.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/infra/store/flowrun \
  -run '^TestReopenForReplay_GuardsTheReversal$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/infra/store/flowrun

mise exec -- go test -race ./internal/infra/store/flowrun \
  -run '^TestReopenForReplay_GuardsTheReversal$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/infra/store/flowrun

mise exec -- go test ./internal/infra/store/flowrun -count=1
ok  github.com/sunweilin/anselm/backend/internal/infra/store/flowrun
```

## Five-level applicability

- L1 pass: the stale replay loses the failed-status guard, returns the stable not-replayable error, leaves the new terminal intact, and does not double `replay_count`.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
