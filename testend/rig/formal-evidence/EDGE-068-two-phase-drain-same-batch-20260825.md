# EDGE-068 · 两阶段 drain 背靠背触发

## Verification

One drain batch containing two firings of the same workflow is evaluated under all four
non-allow-all policies. Phase 1 observes the sibling after claim/seed and phase 2 advances only
the survivors: serial leaves the second pending, skip records it as skipped, replace leaves one
cancelled predecessor and one successful successor, and buffer_one supersedes the older firing and
runs only the newest.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestDrainFiringsTwoPhaseAppliesOverlapToSameBatch$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestDrainFiringsTwoPhaseAppliesOverlapToSameBatch$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

## Five-level applicability

- L1 pass: all four same-batch policy outcomes and durable run/action counts are asserted.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
