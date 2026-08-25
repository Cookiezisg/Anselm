# EDGE-063 · overlap skip 丢弃

## Verification

For a real-trigger firing against a `skip` workflow with one run in flight, the new firing is
settled as a neutral `skipped` firing row. It does not remain pending, does not create a successor
flowrun, and does not dispatch an action. This is intentionally different from `serial`, which
preserves the firing for a later tick.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestFiring_OverlapSerialDefers_SkipDrops$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  0.615s

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestFiring_OverlapSerialDefers_SkipDrops$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  1.787s

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler  1.500s
```

The regression asserts the durable firing status is exactly `skipped`, the pre-existing run is the
only run, and the dispatcher action count remains zero.

## Five-level applicability

- L1 pass: neutral skipped audit, no successor, and no action are tested.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.

