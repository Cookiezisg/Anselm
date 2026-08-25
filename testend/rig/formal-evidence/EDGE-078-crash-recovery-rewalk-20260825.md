# EDGE-078 · 崩溃恢复 Recover

## Verification

Recover enumerates every durable `running` flowrun after a crash and enqueues it onto the advance
pool rather than driving it inline. A completed node row is memoized and skipped; a node whose
row was lost at the crash is re-executed at least once. A slow recovered run therefore cannot block
boot or prevent another recovered run from progressing.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/app/scheduler \
  -run '^(TestCrashRecovery_CompletedRowsSkip|TestPool_RecoverEnqueuesNonInline)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler

mise exec -- go test -race ./internal/app/scheduler \
  -run '^(TestCrashRecovery_CompletedRowsSkip|TestPool_RecoverEnqueuesNonInline)$' -count=1
ok  github.com/sunweilin/anselm/backend/internal/app/scheduler
```

## Five-level applicability

- L1 pass: durable recovery skips completed rows, re-runs the lost row, and enqueues every running run without blocking boot.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
