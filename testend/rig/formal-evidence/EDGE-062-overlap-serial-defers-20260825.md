# EDGE-062 · overlap serial 推迟

## Verification

For a real-trigger firing against a `serial` workflow with one running flowrun, the scheduler
leaves the second firing in the durable pending inbox and does not create a concurrent run. After
the first run is marked completed, the next `DrainFirings` consumes the queued firing and creates
exactly one successor run. The successor dispatches its action once.

This is distinct from `skip`: serial preserves the event and waits for capacity. The test uses the
same firing inbox path as real trigger delivery, not the manual `trigger_workflow` path, which is
explicitly outside overlap policy.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestFiring_OverlapSerialDefers_SkipDrops$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  0.623s

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestFiring_OverlapSerialDefers_SkipDrops$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  1.783s

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  1.483s
```

## Five-level applicability

- L1 pass: durable pending, no overlap, next-tick drain, successor run, and single dispatch are tested.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.

