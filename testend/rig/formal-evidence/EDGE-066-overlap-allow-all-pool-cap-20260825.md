# EDGE-066 · overlap allow_all 并发

## Verification

An eight-firing `allow_all` inbox batch seeds eight independent runs. Four slow actions can enter
at once, matching the structural `advanceWorkers=4` pool ceiling; the fifth cannot enter while all
four workers are held. Releasing the gate lets all eight runs complete and each action dispatches
exactly once. This verifies both high-frequency admission and bounded subprocess fan-out.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^TestConc_AllowAll(HighFrequencyCapsAdvancePool|TwoFiringsBothComplete)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^TestConc_AllowAll(HighFrequencyCapsAdvancePool|TwoFiringsBothComplete)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test ./internal/app/scheduler -run '^(TestConc_AllowAll|TestPool_)' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test ./internal/app/scheduler -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

The first run exposed a test-only input-key mismatch (`holGraph` names the resolved field `flag`),
which was corrected before recording evidence. The production pool and allow_all path were not
weakened.

## Five-level applicability

- L1 pass: eight firings, four-worker admission ceiling, delayed fifth entry, eventual eight completions, and eight action calls are asserted.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
